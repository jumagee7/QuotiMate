// services/html_review_service.dart — Generate a standalone HTML client review page

import "package:intl/intl.dart";
import "../models.dart";
import "../app_state.dart";
import "app_env.dart";

/// Generates a self-contained HTML file the client can open in any browser.
/// Includes the full quotation/invoice layout + a JavaScript signature pad.
/// The client can approve, sign, and download the signed confirmation.
class HtmlReviewService {
  static final _dateFmt = DateFormat("dd MMM yyyy");

  static NumberFormat _fmtFor(AppState state) =>
      NumberFormat.currency(symbol: "${state.currency} ", decimalDigits: 0);

  static String generateQuoteHtml(Quote quote, AppState state, {String? serverUrl}) {
    final items = _buildItemsTable(quote.categories, quote.total, quote.subtotal,
        quote.categoryLabourCost, quote.labourCost, quote.tax, quote.vatPercent,
        _fmtFor(state));
    final expiry = _dateFmt.format(quote.expiryDate);
    final date = _dateFmt.format(quote.date);

    return _buildHtml(
      docType: "Quotation",
      docId: quote.id,
      clientName: quote.clientName,
      clientPhone: _clientPhone(quote.clientId, state),
      date: date,
      expiryOrDue: "Expiry: $expiry",
      status: quote.status.label,
      statusColor: _statusColor(quote.status.name),
      itemsTableHtml: items,
      companyName: state.companyName,
      companyEmail: state.companyEmail,
      companyPhone: state.companyPhone,
      notes: quote.notes,
      serverUrl: serverUrl,
    );
  }

  static String generateInvoiceHtml(Invoice invoice, AppState state, {String? serverUrl}) {
    final items = _buildItemsTable(invoice.categories, invoice.total, invoice.subtotal,
        invoice.categoryLabourCost, invoice.labourCost, invoice.tax, 16.0,
        _fmtFor(state));
    final due = _dateFmt.format(invoice.dueDate);
    final date = _dateFmt.format(invoice.date);

    return _buildHtml(
      docType: "Invoice",
      docId: invoice.id,
      clientName: invoice.clientName,
      clientPhone: _clientPhone(invoice.clientId, state),
      date: date,
      expiryOrDue: "Due: $due",
      status: invoice.status.label,
      statusColor: _statusColor(invoice.status.name),
      itemsTableHtml: items,
      companyName: state.companyName,
      companyEmail: state.companyEmail,
      companyPhone: state.companyPhone,
      notes: invoice.notes,
      serverUrl: serverUrl,
    );
  }

  static String _clientPhone(String clientId, AppState state) {
    for (final c in state.clients) {
      if (c.id == clientId) return c.phone;
    }
    return "";
  }

  static String _statusColor(String status) {
    switch (status) {
      case "approved": case "paid": return "#10B981";
      case "pending": case "sent": return "#F59E0B";
      case "rejected": case "overdue": return "#EF4444";
      case "expired": return "#8B5CF6";
      default: return "#6B7280";
    }
  }

  static String _buildItemsTable(
    List<QuoteCategory> categories,
    double total,
    double subtotal,
    double catLabour,
    double labour,
    double tax,
    double vatPercent,
    NumberFormat fmt,
  ) {
    final sb = StringBuffer();
    for (final cat in categories) {
      sb.writeln("<tr class=\'cat-row\'><td colspan=\'4\'>${_esc(cat.name)}</td></tr>");
      for (final item in cat.items) {
        sb.writeln("""<tr>
          <td>${_esc(item.name)}</td>
          <td style=\'text-align:center\'>${item.qty.toStringAsFixed(0)} ${item.unit}</td>
          <td style=\'text-align:right\'>${fmt.format(item.unitPrice)}</td>
          <td style=\'text-align:right;font-weight:600\'>${fmt.format(item.total)}</td>
        </tr>""");
      }
      if (cat.labourCost > 0) {
        sb.writeln("""<tr class=\'labour-row\'>
          <td colspan=\'3\'>Labour (${cat.name})</td>
          <td style=\'text-align:right\'>${fmt.format(cat.labourCost)}</td>
        </tr>""");
      }
    }
    // Totals
    sb.writeln("""<tr class=\'total-row subtotal-row\'>
      <td colspan=\'3\'>Subtotal</td><td style=\'text-align:right\'>${fmt.format(subtotal)}</td>
    </tr>""");
    if (labour > 0) {
      sb.writeln("""<tr class=\'total-row\'>
        <td colspan=\'3\'>Labour</td><td style=\'text-align:right\'>${fmt.format(labour)}</td>
      </tr>""");
    }
    if (vatPercent > 0) {
      sb.writeln("""<tr class=\'total-row\'>
        <td colspan=\'3\'>VAT (${vatPercent.toStringAsFixed(0)}%)</td>
        <td style=\'text-align:right\'>${fmt.format(tax)}</td>
      </tr>""");
    }
    sb.writeln("""<tr class=\'total-row grand-total\'>
      <td colspan=\'3\'><strong>TOTAL</strong></td>
      <td style=\'text-align:right\'><strong>${fmt.format(total)}</strong></td>
    </tr>""");
    return sb.toString();
  }

  static String _esc(String s) => s
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;");

  static String _buildHtml({
    required String docType,
    required String docId,
    required String clientName,
    String clientPhone = "",
    required String date,
    required String expiryOrDue,
    required String status,
    required String statusColor,
    required String itemsTableHtml,
    required String companyName,
    required String companyEmail,
    required String companyPhone,
    required String notes,
    String? serverUrl,
  }) {
    final configuredServerUrl = serverUrl ?? "";
    final firebaseApiKey = AppEnv.firebaseApiKey;
    final firebaseProjectId = AppEnv.firebaseProjectId;

    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$docType $docId — $companyName</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #1e293b; padding: 16px; }
  .container { max-width: 840px; margin: 24px auto; background: #fff; border-radius: 16px; box-shadow: 0 10px 40px rgba(0,0,0,0.25); overflow: hidden; }
  .header { background: #1E2733; color: #fff; padding: 32px; border-bottom: 3px solid #E7C67B; }
  .header h1 { color: #E7C67B; font-size: 26px; font-weight: 800; letter-spacing: 0.5px; }
  .header .meta { margin-top: 12px; display: flex; flex-wrap: wrap; gap: 16px; font-size: 13px; color: #cbd5e1; align-items: center; }
  .status-badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 700; background: ${statusColor}22; color: $statusColor; border: 1px solid $statusColor; }
  .body { padding: 32px; }
  .client-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 16px 20px; margin-bottom: 24px; }
  .client-box h3 { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #64748b; margin-bottom: 4px; }
  .client-box p { font-size: 17px; font-weight: 700; color: #0f172a; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 24px; font-size: 14px; }
  thead tr { background: #1E2733; color: #E7C67B; }
  thead th { padding: 10px 14px; text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }
  tbody tr:nth-child(even) { background: #f8fafc; }
  tbody td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
  .cat-row td { font-weight: 700; background: #f1f5f9; color: #1e293b; font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
  .labour-row td { color: #64748b; font-size: 13px; font-style: italic; }
  .total-row td { padding: 8px 14px; border-top: 1px solid #e2e8f0; }
  .subtotal-row td { border-top: 2px solid #e2e8f0; }
  .grand-total td { background: #1E2733; color: #E7C67B; font-size: 16px; font-weight: 800; }
  .notes { background: #fffbeb; border-left: 4px solid #E7C67B; padding: 14px 18px; border-radius: 0 8px 8px 0; margin-bottom: 32px; font-size: 13px; color: #78350f; }
  /* Signature Section */
  .sig-section { border-top: 2px solid #e2e8f0; padding-top: 32px; margin-top: 24px; }
  .sig-section h2 { font-size: 20px; font-weight: 800; color: #1E2733; margin-bottom: 8px; }
  .sig-section p { color: #64748b; font-size: 14px; margin-bottom: 16px; }
  #sig-canvas { border: 2px solid #94a3b8; border-radius: 10px; cursor: crosshair; background: #ffffff; touch-action: none; display: block; width: 100%; max-width: 520px; height: 160px; box-shadow: inset 0 2px 4px rgba(0,0,0,0.05); }
  .signer-grid { display: flex; gap: 14px; flex-wrap: wrap; margin-bottom: 18px; }
  .signer-grid label { flex: 1 1 220px; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #64748b; font-weight: 700; }
  .signer-grid input { display: block; width: 100%; margin-top: 6px; padding: 12px 14px; font-size: 15px; font-weight: 600; color: #0f172a; border: 2px solid #cbd5e1; border-radius: 8px; background: #fff; text-transform: none; letter-spacing: 0; }
  .signer-grid input:focus { outline: none; border-color: #E7C67B; }
  .signer-hint { font-size: 12px; color: #64748b; margin: -8px 0 18px; text-transform: none; letter-spacing: 0; font-weight: 400; }
  .sig-actions { margin-top: 14px; display: flex; gap: 12px; flex-wrap: wrap; align-items: center; }
  button { padding: 12px 24px; border-radius: 8px; font-size: 14px; font-weight: 700; cursor: pointer; border: none; transition: all 0.2s; }
  button:hover { opacity: 0.9; }
  #clear-btn { background: #e2e8f0; color: #334155; }
  #approve-btn { background: #E7C67B; color: #1E2733; font-size: 15px; padding: 14px 32px; }
  #approve-btn:disabled { opacity: 0.45; cursor: not-allowed; }
  .success-box { background: #f0fdf4; border: 2px solid #22c55e; border-radius: 12px; padding: 24px; text-align: center; display: none; margin-top: 24px; }
  .success-box h3 { color: #15803d; font-size: 20px; margin-bottom: 8px; }
  .success-box p { color: #166534; font-size: 14px; line-height: 1.5; }
  .sync-feedback { margin: 12px 0; padding: 10px; background: #ffffff; border-radius: 8px; font-size: 13px; border: 1px solid #bbf7d0; }
  .success-btns { display: flex; gap: 12px; justify-content: center; flex-wrap: wrap; margin-top: 16px; }
  #download-btn { background: #1E2733; color: #E7C67B; }
  #copy-code-btn { background: #334155; color: #f8fafc; }
  .footer { text-align: center; padding: 24px; font-size: 12px; color: #64748b; background: #f8fafc; border-top: 1px solid #e2e8f0; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>$companyName</h1>
    <div class="meta">
      <span><strong>$docType</strong> #$docId</span>
      <span>Date: $date</span>
      <span>$expiryOrDue</span>
      <span class="status-badge" id="doc-status-badge">$status</span>
    </div>
  </div>
  <div class="body">
    <div class="client-box">
      <h3>Prepared for</h3>
      <p>$clientName</p>
    </div>
    <table>
      <thead>
        <tr>
          <th>Description</th><th>Qty / Unit</th><th>Unit Price</th><th>Total</th>
        </tr>
      </thead>
      <tbody>$itemsTableHtml</tbody>
    </table>
    ${notes.isNotEmpty ? "<div class=\'notes\'><strong>Notes:</strong> ${_esc(notes)}</div>" : ""}
    
    <!-- Signature Section -->
    <div class="sig-section">
      <h2>✍️ Digital Acceptance & Signature</h2>
      <p>Please review the above $docType. If everything is satisfactory, confirm who is signing, sign inside the box below and click <strong>Approve & Sign Document</strong>.</p>
      <div class="signer-grid">
        <label>Full name of signer
          <input id="signer-name" type="text" autocomplete="name" placeholder="Who is approving this?" value="${_esc(clientName)}">
        </label>
        <label>WhatsApp number
          <input id="signer-phone" type="tel" autocomplete="tel" placeholder="+2547..." value="${_esc(clientPhone)}">
        </label>
      </div>
      <p class="signer-hint">We also record the signing device and time so this acceptance is verifiable later.</p>
      <canvas id="sig-canvas" width="520" height="160"></canvas>
      <div class="sig-actions">
        <button id="clear-btn" onclick="clearSig()">Clear Signature</button>
        <button id="approve-btn" disabled onclick="approveSig()">Approve & Sign Document</button>
      </div>
      <div class="success-box" id="success-box">
        <h3>✅ Document Approved & Signed!</h3>
        <p>Thank you, <strong id="success-signer">$clientName</strong>. Your signature has been recorded.</p>
        <div class="sync-feedback" id="sync-feedback">Connecting to QuotiMate...</div>
        <div class="success-btns">
          <button id="download-btn" onclick="downloadSigned()">⬇ Download Signed Certificate</button>
          <button id="copy-code-btn" onclick="copySigCode()">📋 Copy Verification Code</button>
        </div>
        <div id="copy-feedback" style="margin-top:8px;font-size:12px;color:#15803d;display:none;">✓ Verification code copied to clipboard!</div>
      </div>
    </div>
  </div>
  <div class="footer">$companyName &bull; $companyEmail &bull; $companyPhone &bull; Powered by QuotiMate</div>
</div>

<script>
const docId = "$docId";
const docType = "$docType";
const clientName = "$clientName";
const companyName = "$companyName";
const configuredServer = "$configuredServerUrl";
const isQuote = docType.toLowerCase() === "quotation";

const canvas = document.getElementById("sig-canvas");
const ctx = canvas.getContext("2d");
let drawing = false, hasSig = false;
let lastX = 0, lastY = 0;
let signedDataUrl = null;
let lastSignaturePayload = null;

function getPos(e) {
  const r = canvas.getBoundingClientRect();
  const scaleX = canvas.width / r.width;
  const scaleY = canvas.height / r.height;
  if (e.touches && e.touches[0]) {
    return { x: (e.touches[0].clientX - r.left) * scaleX, y: (e.touches[0].clientY - r.top) * scaleY };
  }
  return { x: (e.clientX - r.left) * scaleX, y: (e.clientY - r.top) * scaleY };
}

canvas.addEventListener("mousedown", e => { drawing = true; const p = getPos(e); lastX = p.x; lastY = p.y; });
canvas.addEventListener("mousemove", e => {
  if (!drawing) return;
  const p = getPos(e);
  ctx.beginPath(); ctx.moveTo(lastX, lastY); ctx.lineTo(p.x, p.y);
  ctx.strokeStyle = "#0f172a"; ctx.lineWidth = 2.5; ctx.lineCap = "round"; ctx.stroke();
  lastX = p.x; lastY = p.y; hasSig = true;
  refreshApproveBtn();
});
canvas.addEventListener("mouseup", () => drawing = false);
canvas.addEventListener("mouseleave", () => drawing = false);

canvas.addEventListener("touchstart", e => {
  e.preventDefault(); drawing = true; const p = getPos(e); lastX = p.x; lastY = p.y;
}, { passive: false });

canvas.addEventListener("touchmove", e => {
  e.preventDefault();
  if (!drawing) return;
  const p = getPos(e);
  ctx.beginPath(); ctx.moveTo(lastX, lastY); ctx.lineTo(p.x, p.y);
  ctx.strokeStyle = "#0f172a"; ctx.lineWidth = 2.5; ctx.lineCap = "round"; ctx.stroke();
  lastX = p.x; lastY = p.y; hasSig = true;
  refreshApproveBtn();
}, { passive: false });

canvas.addEventListener("touchend", () => drawing = false);

function clearSig() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  hasSig = false;
  refreshApproveBtn();
  document.getElementById("success-box").style.display = "none";
}

function refreshApproveBtn() {
  const btn = document.getElementById("approve-btn");
  btn.disabled = !(hasSig && signerNameValue().length >= 2);
}

function signerNameValue() {
  const el = document.getElementById("signer-name");
  return el ? (el.value || "").trim() : "";
}

function signerPhoneValue() {
  const el = document.getElementById("signer-phone");
  return el ? (el.value || "").trim() : "";
}

document.getElementById("signer-name").addEventListener("input", refreshApproveBtn);
document.getElementById("signer-phone").addEventListener("input", refreshApproveBtn);

// The page is served by the app itself, so its own origin is the most reliable
// callback address; the IP baked into the link is only a fallback.
const pageOrigin = /^https?:\\/\\//.test(window.location.origin || "") ? window.location.origin : null;
const localTargets = [];
if (pageOrigin) localTargets.push(pageOrigin);
if (configuredServer && localTargets.indexOf(configuredServer) === -1) localTargets.push(configuredServer);

function fetchWithTimeout(url, options, ms) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), ms);
  return fetch(url, Object.assign({ signal: ctl.signal }, options))
    .then(res => { clearTimeout(timer); return res; })
    .catch(err => { clearTimeout(timer); console.warn("QuotiMate transport notice:", err && err.message); return null; });
}

function browserName(ua) {
  if (/Edg\\//i.test(ua)) return "Edge";
  if (/OPR\\//i.test(ua)) return "Opera";
  if (/Firefox\\//i.test(ua)) return "Firefox";
  if (/Chrome\\//i.test(ua)) return "Chrome";
  if (/Safari\\//i.test(ua)) return "Safari";
  return "Browser";
}

function osName(ua) {
  if (/Android/i.test(ua)) return "Android";
  if (/iPhone|iPad|iPod/i.test(ua)) return "iOS";
  if (/Windows/i.test(ua)) return "Windows";
  if (/Mac OS X/i.test(ua)) return "macOS";
  if (/Linux/i.test(ua)) return "Linux";
  return "Unknown device";
}

function collectEvidence() {
  const ua = navigator.userAgent || "";
  return {
    signerName: signerNameValue(),
    signerPhone: signerPhoneValue(),
    signerDevice: osName(ua) + " - " + browserName(ua) + " (" + ua.substring(0, 90) + ")",
    signerAppVersion: "QuotiMate Web Review - " + screen.width + "x" + screen.height + " " + (navigator.language || ""),
    signerLocation: "Not shared"
  };
}

function locate(evidence) {
  return new Promise(resolve => {
    let settled = false;
    const finish = value => { if (!settled) { settled = true; evidence.signerLocation = value; resolve(); } };
    if (!navigator.geolocation) return finish("Not shared");
    setTimeout(() => finish("Not shared"), 3000);
    navigator.geolocation.getCurrentPosition(
      pos => finish(pos.coords.latitude.toFixed(5) + ", " + pos.coords.longitude.toFixed(5)),
      () => finish("Not shared"),
      { timeout: 3000, maximumAge: 600000, enableHighAccuracy: false }
    );
  });
}

async function approveSig() {
  const approveBtn = document.getElementById("approve-btn");
  if (!hasSig || signerNameValue().length < 2) {
    document.getElementById("signer-name").focus();
    return;
  }
  approveBtn.disabled = true;
  approveBtn.innerText = "Transmitting Signature...";

  signedDataUrl = canvas.toDataURL("image/png");
  const base64Data = signedDataUrl.replace(/^data:image\\/png;base64,/, "");
  const nowIso = new Date().toISOString();

  const evidence = collectEvidence();
  await locate(evidence);

  let sentToCloud = false;
  let sentToLocal = false;

  // 1. Send to Firebase Firestore REST API (only when a Web API key was
  //    supplied at build time; otherwise the local server is the delivery path)
  if (!firebaseApiKey) {
    console.warn("Cloud sync skipped: FIREBASE_API_KEY not configured at build time.");
  } else try {
    const colName = isQuote ? "quotimate_quotes" : "quotimate_invoices";
    const apiKey = "$firebaseApiKey";
    const fields = ["signatureData","signedAt","status","signerName","signerPhone","signerDevice","signerAppVersion","signerLocation"];
    const mask = fields.map(f => "updateMask.fieldPaths=" + f).join("&");
    const firestoreUrl = "https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents/" + colName + "/" + encodeURIComponent(docId) + "?" + mask + "&key=" + apiKey;

    const payload = { fields: {
      signatureData: { stringValue: base64Data },
      signedAt: { stringValue: nowIso },
      status: { stringValue: "approved" },
      signerName: { stringValue: evidence.signerName },
      signerPhone: { stringValue: evidence.signerPhone },
      signerDevice: { stringValue: evidence.signerDevice },
      signerAppVersion: { stringValue: evidence.signerAppVersion },
      signerLocation: { stringValue: evidence.signerLocation }
    }};

    const res = await fetchWithTimeout(firestoreUrl, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    }, 8000);
    if (res && res.ok) {
      sentToCloud = true;
      console.log("Firestore signature updated successfully.");
    } else if (res) {
      console.warn("Firestore returned status", res.status);
    }
  } catch (err) {
    console.warn("Cloud update notice:", err);
  }

  // 2. Send to local QuotiMate HTTP server if available
  for (const target of localTargets) {
    const res = await fetchWithTimeout(target + "/api/sign", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(Object.assign({
        docId: docId,
        docType: docType,
        signatureData: base64Data,
        signedAt: nowIso
      }, evidence))
    }, 6000);
    if (res && res.ok) {
      let applied = true;
      try { const json = await res.json(); applied = json.applied !== false; } catch (err) { applied = true; }
      sentToLocal = applied;
      if (applied) { console.log("Local server signature updated successfully."); break; }
    }
  }

  // 3. Update UI
  const successBox = document.getElementById("success-box");
  const syncMsg = document.getElementById("sync-feedback");
  const badge = document.getElementById("doc-status-badge");
  const signerLabel = document.getElementById("success-signer");
  if (signerLabel) signerLabel.innerText = evidence.signerName;
  if (badge) {
    badge.innerText = "Approved";
    badge.style.background = "#10b98122";
    badge.style.color = "#10b981";
    badge.style.borderColor = "#10b981";
  }

  if (sentToLocal) {
    syncMsg.innerHTML = '<span style="color:#15803d;font-weight:700">✓ Delivered to QuotiMate!</span> The app has your signature and signing details.';
  } else if (sentToCloud) {
    syncMsg.innerHTML = '<span style="color:#15803d;font-weight:700">✓ Saved to the cloud.</span> QuotiMate picks it up the moment the app reconnects.';
  } else {
    syncMsg.innerHTML = '<span style="color:#b45309;font-weight:700">✓ Signed locally!</span> QuotiMate could not be reached from this device, so please download your signed certificate or share the verification code.';
  }

  successBox.style.display = "block";
  approveBtn.innerText = "Approved & Signed ✓";
  successBox.scrollIntoView({ behavior: "smooth" });
  lastSignaturePayload = Object.assign({
    docId: docId,
    docType: docType,
    signedAt: nowIso,
    signatureData: base64Data
  }, evidence);
}

function copySigCode() {
  if (!lastSignaturePayload) return;
  navigator.clipboard.writeText(JSON.stringify(lastSignaturePayload)).then(() => {
    const el = document.getElementById("copy-feedback");
    el.style.display = "block";
    setTimeout(() => { el.style.display = "none"; }, 3500);
  });
}

function downloadSigned() {
  const w = window.open("", "_blank");
  const s = lastSignaturePayload || {};
  const signer = s.signerName || clientName;
  const now = s.signedAt ? new Date(s.signedAt).toLocaleString() : new Date().toLocaleString();
  w.document.write(`<!DOCTYPE html><html><head><meta charset="UTF-8">
    <title>Signed Certificate - \${docType} \${docId}</title>
    <style>body{font-family:sans-serif;max-width:720px;margin:32px auto;padding:24px;color:#1e293b;}
    h1{color:#1E2733;font-size:24px;}h2{color:#E7C67B;background:#1E2733;padding:12px 20px;border-radius:6px;font-size:18px;}
    .sig-img{border:1px solid #cbd5e1;border-radius:6px;margin:12px 0;max-width:380px;height:auto;}
    p{color:#475569;font-size:13px;line-height:1.6;}
    .legal{background:#f8fafc;border:1px solid #e2e8f0;padding:14px;border-radius:6px;font-size:12px;color:#64748b;margin-top:24px;}
    </style></head>
    <body>
    <h1>Digital Signature Certificate</h1>
    <h2>\${docType} #\${docId}</h2>
    <p><strong>Client:</strong> \${clientName}</p>
    <p><strong>Issued by:</strong> \${companyName}</p>
    <p><strong>Signed by:</strong> \${signer}</p>
    <p><strong>WhatsApp:</strong> \${s.signerPhone || "Not provided"}</p>
    <p><strong>Signed on:</strong> \${now}</p>
    <hr style="margin:20px 0;border:0;border-top:1px solid #e2e8f0;">
    <h3>Client Signature</h3>
    <img class="sig-img" src="\${signedDataUrl}" alt="Signature">
    <p><strong>\${signer}</strong></p>
    <div class="legal">This document has been digitally reviewed, accepted, and signed by \${signer} on \${now}.
    Signing device: \${s.signerDevice || "Not captured"} | App: \${s.signerAppVersion || "Not captured"} | Location: \${s.signerLocation || "Not shared"}.
    This signature constitutes binding acceptance of the terms and pricing contained in \${docType} \${docId}.</div>
    </body></html>`);
  w.document.close();
  setTimeout(() => w.print(), 600);
}
</script>
</body>
</html>
""";
  }
}
