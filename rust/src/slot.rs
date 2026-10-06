// Native slot math — a port of the former Dart `Bandit`/`read` in machine.dart.
//
// Every parameter (paytable, scatter tables, reel weights/wild-scatter counts/
// shuffle seeds) is stored XOR-encrypted in the generated `SLOT_PARAMS` blob
// (table.rs) and decrypted here at runtime, so the RTP model is never present as
// plaintext in the binary. The reel strips are rebuilt deterministically from
// those parameters. Spin results are serialized into a flat, length-framed byte
// buffer that Dart decodes over dart:ffi.
//
// SLOT_PARAMS byte layout (shared contract with tool/sleet/plain.dart):
//   [0 ..33)  paytable: 11 kinds x (three, four, five)
//   [33..39)  scatter payout by count 0..5 (x10)
//   [39..45)  scatter free spins by count 0..5
//   [45..54)  normal reel base weights (ten..crown, 9 kinds)
//   [54..63)  hot reel base weights (ten..crown, 9 kinds)
//   [63..68)  normal reel wild counts        (5 reels)
//   [68..73)  normal reel scatter counts     (5 reels)
//   [73..78)  normal reel shuffle seeds      (5 reels)
//   [78..83)  hot reel wild counts           (5 reels)
//   [83..88)  hot reel scatter counts        (5 reels)
//   [88..93)  hot reel shuffle seeds         (5 reels)

use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::crypt::reveal_bytes;
use crate::table::SLOT_PARAMS;

const REELS: usize = 5;
const ROWS: usize = 4;
const KINDS: u8 = 11;
const WILD: u8 = 9;
const SCATTER: u8 = 10;
const CELLS: usize = REELS * ROWS;
const WEIGHT_KINDS: usize = 9; // ten..crown

struct Tables {
    pay: Vec<u8>,       // 11 kinds * 3 (three, four, five)
    spay: Vec<u8>,      // indexed by scatter count 0..=5
    sfree: Vec<u8>,     // indexed by scatter count 0..=5
    base: Vec<Vec<u8>>, // 5 reels
    hot: Vec<Vec<u8>>,  // 5 reels
}

// One step of splitmix64.
fn mix(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E3779B97F4A7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
    z ^ (z >> 31)
}

// Deterministic Fisher-Yates shuffle, seeded so a given reel is stable across
// runs (mirrors the old Dart `bag.shuffle(Random(seed * 97 + 13))` intent).
fn shuffle(bag: &mut [u8], seed: u64) {
    let mut state = seed | 1;
    let mut i = bag.len();
    while i > 1 {
        i -= 1;
        let r = mix(&mut state);
        let j = (r % (i as u64 + 1)) as usize;
        bag.swap(i, j);
    }
}

fn weave(weights: &[u8], wild: u8, scatter: u8, seed: u8) -> Vec<u8> {
    let mut bag: Vec<u8> = Vec::new();
    for k in 0..WEIGHT_KINDS {
        for _ in 0..weights[k] {
            bag.push(k as u8);
        }
    }
    for _ in 0..wild {
        bag.push(WILD);
    }
    for _ in 0..scatter {
        bag.push(SCATTER);
    }
    shuffle(&mut bag, (seed as u64).wrapping_mul(97).wrapping_add(13));
    bag
}

fn tables() -> &'static Tables {
    static T: OnceLock<Tables> = OnceLock::new();
    T.get_or_init(|| {
        let p = reveal_bytes(SLOT_PARAMS);
        let pay = p[0..33].to_vec();
        let spay = p[33..39].to_vec();
        let sfree = p[39..45].to_vec();
        let wn = &p[45..54];
        let wh = &p[54..63];
        let n_wild = &p[63..68];
        let n_scat = &p[68..73];
        let n_seed = &p[73..78];
        let h_wild = &p[78..83];
        let h_scat = &p[83..88];
        let h_seed = &p[88..93];
        let base = (0..REELS)
            .map(|r| weave(wn, n_wild[r], n_scat[r], n_seed[r]))
            .collect();
        let hot = (0..REELS)
            .map(|r| weave(wh, h_wild[r], h_scat[r], h_seed[r]))
            .collect();
        Tables {
            pay,
            spay,
            sfree,
            base,
            hot,
        }
    })
}

// splitmix64 PRNG for spin stops, seeded once from the wall clock. Good enough
// for a play-money slot; stops are the only per-spin randomness.
fn rng_next() -> u64 {
    static STATE: AtomicU64 = AtomicU64::new(0);
    let mut cur = STATE.load(Ordering::Relaxed);
    if cur == 0 {
        let seed = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0x9E3779B97F4A7C15)
            | 1;
        let _ = STATE.compare_exchange(0, seed, Ordering::Relaxed, Ordering::Relaxed);
        cur = STATE.load(Ordering::Relaxed);
    }
    let mut state = cur;
    let r = mix(&mut state);
    STATE.store(state, Ordering::Relaxed);
    r
}

fn rng_below(n: usize) -> usize {
    if n == 0 {
        return 0;
    }
    (rng_next() % n as u64) as usize
}

fn pay(t: &Tables, kind: u8, length: usize) -> i64 {
    let slot = if length >= 5 {
        2
    } else if length == 4 {
        1
    } else if length == 3 {
        0
    } else {
        return 0;
    };
    t.pay[kind as usize * 3 + slot] as i64
}

struct Hit {
    kind: u8,
    length: u8,
    ways: u32,
    payout: i64,
    mask: [bool; CELLS],
}

struct Spin {
    used_flag: u8,
    stops: [usize; REELS],
    grid: [u8; CELLS],
    scatter_count: u8,
    scatter_payoff: i64,
    free_awarded: u16,
    paid: i64,
    hits: Vec<Hit>,
}

fn evaluate(
    used: &[Vec<u8>],
    stops: &[usize; REELS],
    stake: i64,
    bonus: bool,
    used_flag: u8,
) -> Spin {
    let mut grid = [0u8; CELLS];
    for r in 0..REELS {
        let strip = &used[r];
        let len = strip.len();
        for y in 0..ROWS {
            grid[r * ROWS + y] = strip[(stops[r] + y) % len];
        }
    }

    let t = tables();
    let mut hits: Vec<Hit> = Vec::new();
    for kind in 0..KINDS {
        if kind == SCATTER {
            continue;
        }
        let mut mask = [false; CELLS];
        let mut length = 0usize;
        let mut ways: u32 = 1;
        for r in 0..REELS {
            let mut n = 0u32;
            for y in 0..ROWS {
                let cell = grid[r * ROWS + y];
                let ok = if kind == WILD {
                    cell == WILD
                } else {
                    cell == kind || cell == WILD
                };
                if ok {
                    n += 1;
                    mask[r * ROWS + y] = true;
                }
            }
            if n == 0 {
                break;
            }
            ways = ways.wrapping_mul(n);
            length += 1;
        }
        let unit = pay(t, kind, length);
        if unit > 0 {
            let payout = stake * unit * ways as i64 / 10;
            hits.push(Hit {
                kind,
                length: length as u8,
                ways,
                payout,
                mask,
            });
        }
    }

    let mut scatters = 0u8;
    for &c in grid.iter() {
        if c == SCATTER {
            scatters += 1;
        }
    }
    let sc = scatters as usize;
    let spay_unit = if sc < t.spay.len() { t.spay[sc] as i64 } else { 0 };
    let scatter_payoff = stake * spay_unit / 10;
    let mut free = if sc < t.sfree.len() {
        t.sfree[sc] as u16
    } else {
        0
    };
    if bonus && free > 0 {
        free = 5;
    }

    let mut paid: i64 = hits.iter().map(|h| h.payout).sum();
    paid += scatter_payoff;

    Spin {
        used_flag,
        stops: *stops,
        grid,
        scatter_count: scatters,
        scatter_payoff,
        free_awarded: free,
        paid,
        hits,
    }
}

fn spin(stake: i64, bonus: bool) -> Spin {
    let t = tables();
    let used = if bonus { &t.hot } else { &t.base };
    let mut stops = [0usize; REELS];
    for r in 0..REELS {
        stops[r] = rng_below(used[r].len());
    }
    evaluate(used, &stops, stake, bonus, if bonus { 1 } else { 0 })
}

// ── serialization (little-endian) ────────────────────────────────────────────

fn put_u16(v: &mut Vec<u8>, x: u16) {
    v.extend_from_slice(&x.to_le_bytes());
}

fn put_u32(v: &mut Vec<u8>, x: u32) {
    v.extend_from_slice(&x.to_le_bytes());
}

fn put_i64(v: &mut Vec<u8>, x: i64) {
    v.extend_from_slice(&x.to_le_bytes());
}

/// Prepends a 4-byte little-endian total length (header + payload) so Dart can
/// read the size from the buffer itself and needs no out-parameter.
fn frame(payload: Vec<u8>) -> Vec<u8> {
    let total = (payload.len() + 4) as u32;
    let mut buf = Vec::with_capacity(total as usize);
    buf.extend_from_slice(&total.to_le_bytes());
    buf.extend_from_slice(&payload);
    buf
}

fn serialize_spin(s: &Spin) -> Vec<u8> {
    let mut p: Vec<u8> = Vec::new();
    p.push(s.used_flag);
    for r in 0..REELS {
        put_u16(&mut p, s.stops[r] as u16);
    }
    p.extend_from_slice(&s.grid);
    p.push(s.scatter_count);
    put_i64(&mut p, s.scatter_payoff);
    put_u16(&mut p, s.free_awarded);
    put_i64(&mut p, s.paid);
    p.push(s.hits.len() as u8);
    for h in &s.hits {
        p.push(h.kind);
        p.push(h.length);
        put_u32(&mut p, h.ways);
        put_i64(&mut p, h.payout);
        for b in h.mask.iter() {
            p.push(if *b { 1 } else { 0 });
        }
    }
    frame(p)
}

fn serialize_strips() -> Vec<u8> {
    let t = tables();
    let mut p: Vec<u8> = Vec::new();
    p.push(REELS as u8);
    for set in [&t.base, &t.hot] {
        for r in 0..REELS {
            let reel = &set[r];
            put_u16(&mut p, reel.len() as u16);
            p.extend_from_slice(reel);
        }
    }
    frame(p)
}

fn serialize_paytable() -> Vec<u8> {
    frame(tables().pay.clone())
}

fn into_raw(buf: Vec<u8>) -> *mut u8 {
    Box::into_raw(buf.into_boxed_slice()) as *mut u8
}

// ── C-ABI exports ────────────────────────────────────────────────────────────

/// Returns the reel strips (base + hot) as a length-framed buffer. Release with
/// `slot_free`.
#[no_mangle]
pub extern "C" fn slot_strips() -> *mut u8 {
    into_raw(serialize_strips())
}

/// Returns the paytable (11 kinds * 3 tiers) as a length-framed buffer. Release
/// with `slot_free`.
#[no_mangle]
pub extern "C" fn slot_paytable() -> *mut u8 {
    into_raw(serialize_paytable())
}

/// Evaluates one spin and returns a length-framed outcome buffer. `bonus` != 0
/// selects the hot (free-spin) strips. Release with `slot_free`.
#[no_mangle]
pub extern "C" fn slot_spin(stake: i64, bonus: u8) -> *mut u8 {
    into_raw(serialize_spin(&spin(stake, bonus != 0)))
}

/// Releases a buffer previously returned by any `slot_*` call. `len` must be the
/// total length read from the buffer's 4-byte header.
#[no_mangle]
pub extern "C" fn slot_free(ptr: *mut u8, len: u64) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let s = std::slice::from_raw_parts_mut(ptr, len as usize);
        let _ = Box::from_raw(s as *mut [u8]);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn s(v: &[u8]) -> Vec<u8> {
        v.to_vec()
    }

    // crown = 8, scatter = 10; kinds: ten0 jack1 queen2 king3 ...
    #[test]
    fn three_crowns_from_the_left_pay() {
        let used = vec![
            s(&[8, 0, 1, 2]),
            s(&[8, 0, 1, 2]),
            s(&[8, 0, 1, 2]),
            s(&[0, 1, 2, 3]),
            s(&[0, 1, 2, 3]),
        ];
        let out = evaluate(&used, &[0usize, 0, 0, 0, 0], 100, false, 0);
        assert!(out.hits.iter().any(|h| h.kind == 8 && h.length == 3));
        assert!(out.paid > 0);
    }

    #[test]
    fn dead_grid_never_pays() {
        let used = vec![
            s(&[0, 1, 2, 3]),
            s(&[4, 5, 6, 7]),
            s(&[0, 1, 2, 3]),
            s(&[4, 5, 6, 7]),
            s(&[0, 1, 2, 3]),
        ];
        let out = evaluate(&used, &[0usize, 0, 0, 0, 0], 500, false, 0);
        assert_eq!(out.paid, 0);
        assert_eq!(out.free_awarded, 0);
        assert!(out.hits.is_empty());
    }

    #[test]
    fn three_scatters_award_free_spins() {
        let used = vec![
            s(&[10, 0, 1, 2]),
            s(&[10, 0, 1, 2]),
            s(&[10, 0, 1, 2]),
            s(&[0, 1, 2, 3]),
            s(&[0, 1, 2, 3]),
        ];
        let out = evaluate(&used, &[0usize, 0, 0, 0, 0], 100, false, 0);
        assert_eq!(out.scatter_count, 3);
        assert_eq!(out.free_awarded, 8);
    }

    #[test]
    fn params_decrypt_to_expected_shape() {
        let t = tables();
        assert_eq!(t.pay.len(), KINDS as usize * 3);
        assert_eq!(t.spay.len(), 6);
        assert_eq!(t.sfree.len(), 6);
        assert_eq!(t.base.len(), REELS);
        assert_eq!(t.hot.len(), REELS);
        // paytable sanity: crown (kind 8) five-of-a-kind pays 100 (x10)
        assert_eq!(t.pay[8 * 3 + 2], 100);
        // scatter tables sanity
        assert_eq!(t.spay[3], 20);
        assert_eq!(t.sfree[5], 20);
        // every reel symbol id is a valid kind and reels are non-empty
        for set in [&t.base, &t.hot] {
            for reel in set {
                assert!(!reel.is_empty());
                assert!(reel.iter().all(|&c| c < KINDS));
            }
        }
    }
}
