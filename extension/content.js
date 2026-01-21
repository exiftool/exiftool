/**
 * WhatsApp Bridge Content Script
 * Intercepts media clicks and fetches metadata from the Architect Backend.
 */

console.log("ExifTool Architect Bridge: Active");

document.addEventListener("click", async (e) => {
  const target = e.target;
  if (target.tagName === "IMG" && target.closest(".copyable-text")) {
    const src = target.src;
    if (src.startsWith("blob:")) {
      showOverlay("Analyzing encrypted media buffer...");
      try {
        const blob = await fetch(src).then((r) => r.blob());
        const formData = new FormData();
        formData.append("file", blob, "whatsapp_media.jpg");

        const response = await fetch("http://localhost:3001/api/metadata", {
          method: "POST",
          body: formData,
        });

        const metadata = await response.json();
        updateOverlay(metadata);
      } catch (err) {
        showOverlay("Bridge Error: " + err.message, true);
      }
    }
  }
});

let overlay = null;

function showOverlay(message, isError = false) {
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "architect-bridge-overlay";
    document.body.appendChild(overlay);
  }
  overlay.innerHTML = `
    <div class="bridge-card ${isError ? "error" : "loading"}">
      <div class="bridge-header">
        <span class="bridge-title">ARCHITECT BRIDGE</span>
        <button onclick="this.parentElement.parentElement.remove()">×</button>
      </div>
      <div class="bridge-content">${message}</div>
    </div>
  `;
}

function updateOverlay(metadata) {
  if (!overlay) return;
  const items = Object.entries(metadata)
    .slice(0, 10)
    .map(
      ([k, v]) => `
      <div class="metadata-row">
        <span class="metadata-key">${k}</span>
        <span class="metadata-value">${String(v).substring(0, 30)}${String(v).length > 30 ? "..." : ""}</span>
      </div>
    `,
    )
    .join("");

  overlay.innerHTML = `
    <div class="bridge-card active">
      <div class="bridge-header">
        <span class="bridge-title">METADATA EXTRACTED</span>
        <button onclick="document.getElementById('architect-bridge-overlay').remove()">×</button>
      </div>
      <div class="bridge-content">
        ${items}
        <div class="bridge-footer">Open Architect App for full report</div>
      </div>
    </div>
  `;
}
