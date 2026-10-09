// EasyFreezy native HTTP transport.
//
// Why this isn't Dart `package:http`: Cloudflare fingerprints the ClientHello
// (JA3/JA4) and sends 403 to anything whose TLS parameters don't match a real
// browser — stock rustls, ureq and Dart http all look non-browserish and get
// cut. The only reliable fix is a BoringSSL-backed client whose TLS cipher
// list, extensions, HTTP/2 settings and User-Agent are the SAME pair that
// Chrome ships. `wreq + wreq_util::Profile::Chrome134` does exactly that: the
// emulation layer sets both the fingerprint AND the UA, so we must NOT
// override User-Agent from the outside (a browser-ish UA on a non-browser
// handshake is itself a WAF signal, which was the first failure mode we hit).
//
// FFI contract (consumed by lib/sleet/post.dart over dart:ffi):
//
//   sleet_post_config(body_ptr, body_len, timeout_secs)
//     -> C string "{status}\n{body}" (caller frees with sleet_free)
//
// `status` is the HTTP status as decimal (200, 403, 500, …). Transport-level
// failure (DNS, TLS, timeout, decode) collapses to status 0 and the body
// carries a short error tag — the Dart side treats any status != 200 as a
// rejection, so the exact text is purely diagnostic.
//
// Everything the request needs — URL, method, header names, MIME — lives
// encrypted in table.rs and is decrypted here, per call. Nothing crosses the
// FFI boundary in plaintext except the compact "{status}\n{body}" result.

use std::ffi::CString;
use std::os::raw::{c_char, c_uchar};
use std::sync::OnceLock;
use std::time::Duration;

use tokio::runtime::{Builder as RuntimeBuilder, Runtime};
use wreq::header::{HeaderName, HeaderValue};
use wreq::{Client, Method};
use wreq_util::Profile;

use crate::crypt::reveal;
use crate::table::{
    DATA, ID_ENDPOINT, ID_HEADER_ACCEPT, ID_HEADER_CONTENT_TYPE, ID_HTTP_METHOD, ID_MIME_JSON,
};

/// Shared current-thread runtime. Rebuilding Tokio on every call would waste
/// several milliseconds per request and leak thread handles on hot retries,
/// so we lazy-init once and reuse. Current-thread is enough because the FFI
/// entry already runs on whatever Dart worker invoked it.
fn rt() -> &'static Runtime {
    static CELL: OnceLock<Runtime> = OnceLock::new();
    CELL.get_or_init(|| {
        RuntimeBuilder::new_current_thread()
            .enable_all()
            .build()
            .expect("tokio current-thread runtime")
    })
}

/// Builds (and caches) the Chrome 134 emulated client. Any failure here is
/// fatal — we fall back to a bare client with just the emulation applied so
/// at least the TLS fingerprint matches, rather than silently reverting to a
/// non-emulated handshake that WAF rules will shred.
fn client(connect_secs: u64, total_secs: u64) -> &'static Client {
    static CELL: OnceLock<Client> = OnceLock::new();
    CELL.get_or_init(|| {
        Client::builder()
            // Profile::Chrome134 implements IntoEmulation and sets TLS, HTTP/2,
            // header order AND the Chrome User-Agent in one shot. Do NOT add
            // a .user_agent() call anywhere — the TLS fingerprint and UA must
            // ship as one coherent pair, otherwise Cloudflare's bot score
            // flags the mismatch.
            .emulation(Profile::Chrome134)
            .connect_timeout(Duration::from_secs(connect_secs))
            .timeout(Duration::from_secs(total_secs))
            .build()
            .unwrap_or_else(|_| Client::builder().emulation(Profile::Chrome134).build().unwrap())
    })
}

fn table_str(id: usize) -> String {
    reveal(DATA[id])
}

/// Shapes an outbound-ready `(url, method, body)` + headers from the
/// encrypted table and the caller-supplied body bytes. Returns `Err` with a
/// short tag if any header name/value or method is malformed — those cases
/// collapse to status 0 at the FFI boundary.
async fn perform(body: Vec<u8>, timeout_secs: u64) -> Result<(u16, String), &'static str> {
    let url = table_str(ID_ENDPOINT);
    let method_s = table_str(ID_HTTP_METHOD);
    let hdr_accept_s = table_str(ID_HEADER_ACCEPT);
    let hdr_ct_s = table_str(ID_HEADER_CONTENT_TYPE);
    let mime_s = table_str(ID_MIME_JSON);

    if url.is_empty() {
        return Err("no_url");
    }

    let method = Method::from_bytes(method_s.as_bytes()).map_err(|_| "bad_method")?;
    let hn_accept = HeaderName::from_bytes(hdr_accept_s.as_bytes()).map_err(|_| "bad_header")?;
    let hn_ct = HeaderName::from_bytes(hdr_ct_s.as_bytes()).map_err(|_| "bad_header")?;
    let hv_mime = HeaderValue::from_str(&mime_s).map_err(|_| "bad_mime")?;

    // Connect timeout is a modest slice of the overall budget; the WAF edge
    // sometimes stalls on handshake alone.
    let connect = timeout_secs.min(10).max(3);
    let cli = client(connect, timeout_secs);

    let resp = cli
        .request(method, &url)
        .header(hn_accept, hv_mime.clone())
        .header(hn_ct, hv_mime)
        .body(body)
        .send()
        .await
        .map_err(|_| "send_fail")?;

    let status = resp.status().as_u16();
    let text = resp.text().await.unwrap_or_default();
    Ok((status, text))
}

/// FFI entry: POST the given body (owned raw bytes) to the native-only config
/// endpoint and return the response as a freshly allocated C string of the
/// form `"{status}\n{body}"`. Transport errors return `"0\n{tag}"`. Caller
/// must release the pointer with `sleet_free`.
///
/// # Safety
///
/// `body_ptr` must point to `body_len` initialised bytes (or be null when
/// `body_len == 0`). The pointer is only read for the duration of the call;
/// ownership stays with the caller.
#[no_mangle]
pub unsafe extern "C" fn sleet_post_config(
    body_ptr: *const c_uchar,
    body_len: u32,
    timeout_secs: u32,
) -> *mut c_char {
    let body: Vec<u8> = if body_ptr.is_null() || body_len == 0 {
        Vec::new()
    } else {
        std::slice::from_raw_parts(body_ptr, body_len as usize).to_vec()
    };
    let timeout = if timeout_secs == 0 { 22 } else { timeout_secs as u64 };

    let out = match rt().block_on(perform(body, timeout)) {
        Ok((status, body)) => format!("{}\n{}", status, body),
        Err(tag) => format!("0\n{}", tag),
    };

    CString::new(out)
        .unwrap_or_else(|_| CString::new("0\nencode").unwrap())
        .into_raw()
}
