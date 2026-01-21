/**
 * ExifTool Architect: OSINT Modules Library
 * Modular intelligence tools for realtime analysis.
 */

const OSINT = {
  // --- IDENTIFIERS & REGEX ---
  patterns: {
    // International phone regex (simplified)
    phone: /(?:\+|00)[1-9][0-9 \-\(\)\.]{7,32}/g,
    // Email regex
    email: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
    // Crypto Address (BTC, ETH) - Simplified
    crypto: /(?:0x[a-fA-F0-9]{40})|(?:[13][a-km-zA-HJ-NP-Z1-9]{25,34})/g,
    // URL / Domain
    url: /(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)/g,
  },

  // --- MODULES ---

  Media: {
    getReverseSearchLinks: (imageUrl) => {
      const encoded = encodeURIComponent(imageUrl);
      return [
        {
          name: "Google Lens",
          url: `https://lens.google.com/uploadbyurl?url=${encoded}`,
        },
        {
          name: "Yandex",
          url: `https://yandex.com/images/search?rpt=imageview&url=${encoded}`,
        },
        {
          name: "Bing",
          url: `https://www.bing.com/images/search?view=detailv2&iss=sbi&form=SBIHMP&sbisrc=UrlPaste&q=imgurl:${encoded}`,
        },
      ];
    },
  },

  Identity: {
    analyzePhone: (number) => {
      const cleanNum = number.replace(/[^0-9]/g, "");
      return [
        { name: "WhatsApp Direct", url: `https://wa.me/${cleanNum}` },
        {
          name: "TrueCaller",
          url: `https://www.truecaller.com/search/global/${cleanNum}`,
        },
        { name: "Sync.me", url: `https://sync.me/search/?number=${cleanNum}` },
      ];
    },
    checkUsername: (username) => {
      return [
        {
          name: "Sherlock (Google)",
          url: `https://www.google.com/search?q="${username}"+site:instagram.com+OR+site:twitter.com+OR+site:github.com`,
        },
        { name: "WhatsMyName", url: `https://whatsmyname.app/?q=${username}` },
      ];
    },
  },

  Network: {
    analyzeDomain: (domain) => {
      // Clean domain from URL
      let cleanDomain = domain
        .replace(/^(?:https?:\/\/)?(?:www\.)?/i, "")
        .split("/")[0];
      return [
        { name: "Whois", url: `https://who.is/whois/${cleanDomain}` },
        {
          name: "VirusTotal",
          url: `https://www.virustotal.com/gui/domain/${cleanDomain}`,
        },
        { name: "UrlScan", url: `https://urlscan.io/search/#${cleanDomain}` },
      ];
    },
  },

  // --- UTILS ---
  extractEntities: (text) => {
    const results = [];
    for (const [type, regex] of Object.entries(OSINT.patterns)) {
      let match;
      while ((match = regex.exec(text)) !== null) {
        results.push({ type, value: match[0], index: match.index });
      }
    }
    return results;
  },
};

// Expose to window for content script usage
window.OSINT = OSINT;
