// Shared keystream for the gray layer. This is a direct port of
// lib/sleet/mixer.dart, so bytes folded on the Dart/generator side decode here
// and vice-versa. Used both by the generated string table (table.rs) and the
// slot-math parameters (slot.rs).

const SPICE: [u8; 18] = [
    0x17, 0xC4, 0x5B, 0x8E, 0x22, 0xA9, 0x63, 0xD1, 0x4F, 0x90, 0x0C, 0xE6, 0x3D,
    0x71, 0xB8, 0x14, 0x59, 0xAE,
];
const SPAN: usize = 33;

fn tape() -> [u8; SPAN] {
    let mut state: u32 = 0xC2B2AE35;
    let mut i = 0usize;
    while i < SPICE.len() {
        state = state
            .wrapping_add(SPICE[i] as u32)
            .wrapping_add((i as u32).wrapping_mul(0x045D9F3B));
        state ^= state >> 16;
        i += 1;
    }
    if state == 0 {
        state = 0x6C8E9CF5;
    }
    let mut out = [0u8; SPAN];
    let mut j = 0usize;
    while j < SPAN {
        state = state.wrapping_add(0x6C078965);
        let mut z = state;
        z = (z ^ (z >> 16)).wrapping_mul(0x7FEB352D);
        z = (z ^ (z >> 15)).wrapping_mul(0x846CA68B);
        z ^= z >> 16;
        out[j] = z.wrapping_add((j as u32).wrapping_mul(13)) as u8;
        j += 1;
    }
    out
}

/// XOR the encrypted payload back to its plaintext bytes.
pub(crate) fn reveal_bytes(enc: &[u8]) -> Vec<u8> {
    let t = tape();
    let mut out = Vec::with_capacity(enc.len());
    let mut i = 0usize;
    while i < enc.len() {
        let m = t[i % SPAN] ^ (i.wrapping_mul(29) as u8);
        out.push(enc[i] ^ m);
        i += 1;
    }
    out
}

/// Convenience string wrapper around [`reveal_bytes`].
pub(crate) fn reveal(enc: &[u8]) -> String {
    String::from_utf8_lossy(&reveal_bytes(enc)).into_owned()
}
