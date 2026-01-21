/**
 * WhatsApp Bridge Content Script (Realtime OSINT Version)
 * Intercepts media, analyzes messages, and overlays intelligence.
 */

// Wait for OSINT module to load
const waitForOSINT = () => {
  return new Promise((resolve) => {
    if (window.OSINT) return resolve(window.OSINT);
    setTimeout(() => resolve(window.OSINT || waitForOSINT()), 100);
  });
};

// --- CORE ---

async function initBridge() {
  console.log("ExifTool Architect Bridge: Initializing...");
  await waitForOSINT();
  console.log("OSINT Modules: Loaded");

  // Observer for new messages
  const observer = new MutationObserver(handleMutations);
  observer.observe(document.body, { childList: true, subtree: true });

  // Initial scan
  scanVisibleMessages();
}

// Debounce helper
let scanTimeout;
function handleMutations(mutations) {
  if (scanTimeout) clearTimeout(scanTimeout);
  scanTimeout = setTimeout(scanVisibleMessages, 500);
}

function scanVisibleMessages() {
  // Find message containers (WhatsApp Web classes change often, targeting generalized selectors)
  // 'selectable-text' is a common class for message text in WA Web
  const messages = document.querySelectorAll(".selectable-text span");

  messages.forEach((msg) => {
    if (msg.dataset.osintScanned) return;

    const text = msg.innerText;
    const entities = window.OSINT.extractEntities(text);

    if (entities.length > 0) {
      highlightEntities(msg, entities);
      msg.dataset.osintScanned = "true";
    }
  });

  // Media Inteception
  const images = document.querySelectorAll('img[src^="blob:"]');
  images.forEach((img) => {
    if (img.dataset.osintScanned) return;
    img.style.border = "2px solid #6366f1"; // Visual indicator
    img.dataset.osintScanned = "true";

    // Add click listener for analysis
    img.closest('div[role="button"]')?.addEventListener("click", (e) => {
      // In a real scenario, we might need to intercept the blob click or use a context menu
      // For now, let's attach a Floating Action Button (FAB) to the image container
      attachMediaFab(img);
    });

    // Auto-attach FAB if image is large enough (chat image)
    if (img.width > 100) attachMediaFab(img);
  });
}

// --- UI HELPERS ---

function highlightEntities(node, entities) {
  // Simple highlighting: Underline found entities
  // Note: Replacing innerHTML in React/WA web apps can break state.
  // Safer approach: Add a small indicator icon next to the message.

  const parent = node.closest("[data-id]");
  if (!parent) return;

  if (parent.querySelector(".osint-indicator")) return;

  const indicator = document.createElement("span");
  indicator.className = "osint-indicator";
  indicator.innerText = "🛡️"; // Shield icon
  indicator.title = `Found: ${entities.map((e) => e.type).join(", ")}`;
  indicator.onclick = (e) => {
    e.stopPropagation();
    showEntityDashboard(entities);
  };

  node.parentElement.appendChild(indicator);
}

function attachMediaFab(imgNode) {
  const container = imgNode.parentElement;
  if (container.querySelector(".osint-media-fab")) return;

  const fab = document.createElement("button");
  fab.className = "osint-media-fab";
  fab.innerHTML = "🔍";
  fab.title = "Analyze Media";
  fab.onclick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    analyzeMedia(imgNode.src);
  };

  container.style.position = "relative";
  container.appendChild(fab);
}

// --- DASHBOARDS ---

function showEntityDashboard(entities) {
  const content = entities
    .map((entity) => {
      let actions = [];

      if (entity.type === "phone") {
        actions = window.OSINT.Identity.analyzePhone(entity.value);
      } else if (entity.type === "url") {
        actions = window.OSINT.Network.analyzeDomain(entity.value);
      } else {
        actions = [{ name: "Copy", url: "#" }];
      }

      const actionButtons = actions
        .map(
          (act) =>
            `<a href="${act.url}" target="_blank" class="osint-action-btn">${act.name}</a>`,
        )
        .join("");

      return `
      <div class="osint-entity-row">
        <div class="osint-entity-header">
          <span class="osint-type">${entity.type.toUpperCase()}</span>
          <span class="osint-value">${entity.value}</span>
        </div>
        <div class="osint-actions">${actionButtons}</div>
      </div>
    `;
    })
    .join("");

  showOverlay(`
    <div class="bridge-card active">
      <div class="bridge-header">
        <span class="bridge-title">INTELLIGENCE REPORT</span>
        <button onclick="document.getElementById('architect-bridge-overlay').remove()">×</button>
      </div>
      <div class="bridge-content space-y-2">
        ${content}
      </div>
    </div>
  `);
}

async function analyzeMedia(blobUrl) {
  showOverlay("Extracting Media Data...", false);

  // 1. Get Blob
  try {
    const blob = await fetch(blobUrl).then((r) => r.blob());

    // 2. Prepare Reverse Search Links (Mock URL for now as we can't upload to public reversal from here easily without backend)
    // NOTE: Real reverse search requires a public URL.
    // We will use the backend to upload to a temp host OR just show Metadata for now.

    // 3. Get Metadata
    const formData = new FormData();
    formData.append("file", blob, "wa_media.jpg");

    const response = await fetch("http://localhost:3001/api/metadata", {
      method: "POST",
      body: formData,
    });
    const metadata = await response.json();

    // 4. Update Overlay
    updateMediaOverlay(metadata, blob);
  } catch (e) {
    showOverlay("Analysis Failed: " + e.message, true);
  }
}

function updateMediaOverlay(metadata, blob) {
  // Generate dummy URL for reverse search (In real app, we'd enable a temporary public link via backend)
  const reverseLinks = window.OSINT.Media.getReverseSearchLinks(
    "https://example.com/placeholder.jpg",
  ); // Placeholder

  const metaHtml = Object.entries(metadata)
    .slice(0, 5)
    .map(
      ([k, v]) =>
        `<div class="metadata-row"><span class="metadata-key">${k}</span><span class="metadata-value">${String(v).substring(0, 20)}</span></div>`,
    )
    .join("");

  const toolsHtml = reverseLinks
    .map(
      (link) =>
        `<a href="${link.url}" target="_blank" class="osint-action-btn">${link.name}</a>`,
    )
    .join("");

  showOverlay(`
    <div class="bridge-card active">
      <div class="bridge-header">
        <span class="bridge-title">MEDIA INTELLIGENCE</span>
        <button onclick="document.getElementById('architect-bridge-overlay').remove()">×</button>
      </div>
      <div class="bridge-content">
        <div class="osint-section-title">METADATA</div>
        ${metaHtml}
        <div class="osint-section-title" style="margin-top:10px;">REVERSE SEARCH (Demo)</div>
        <div class="osint-actions">${toolsHtml}</div>
      </div>
    </div>
  `);
}

// --- OVERLAY SYSTEM (Reused from previous) ---
let overlay = null;
function showOverlay(html, isError = false) {
  if (overlay) overlay.remove();

  overlay = document.createElement("div");
  overlay.id = "architect-bridge-overlay";

  if (!html.includes("bridge-card")) {
    overlay.innerHTML = `
      <div class="bridge-card ${isError ? "error" : "loading"}">
        <div class="bridge-header">
          <span class="bridge-title">ARCHITECT BRIDGE</span>
          <button onclick="this.parentElement.parentElement.remove()">×</button>
        </div>
        <div class="bridge-content">${html}</div>
      </div>
    `;
  } else {
    overlay.innerHTML = html;
  }

  document.body.appendChild(overlay);
}

// Start
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initBridge);
} else {
  initBridge();
}
