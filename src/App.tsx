import React, { useState, useEffect } from "react";
import {
  Upload,
  Image as ImageIcon,
  Settings,
  ShieldCheck,
  AlertCircle,
  ArrowRight,
  Fingerprint,
  Search,
  MapPin,
  Terminal,
  Download,
  Box,
  Map as MapIcon,
} from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

// --- Custom Hook: useLocalStorage ---
function useLocalStorage<T>(
  key: string,
  initialValue: T,
): [T, (val: T | ((v: T) => T)) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      return initialValue;
    }
  });

  const setValue = (value: T | ((val: T) => T)) => {
    try {
      const valueToStore =
        value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {}
  };

  return [storedValue, setValue];
}

// --- Types ---
interface Metadata {
  [key: string]: any;
}

interface HistoryItem {
  id: string;
  name: string;
  timestamp: string;
  metadata: Metadata;
}

interface LegacyFeatures {
  fmts: string[];
  args: string[];
  configs: string[];
}

// --- Animation Variants ---
const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const itemVariants = {
  hidden: { y: 20, opacity: 0 },
  visible: { y: 0, opacity: 1 },
};

export default function App() {
  const [file, setFile] = useState<File | null>(null);
  const [metadata, setMetadata] = useState<Metadata | null>(null);
  const [outputLog, setOutputLog] = useState<string | null>(null); // For non-JSON output
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [version, setVersion] = useState<string>("Loading...");
  const [history, setHistory] = useLocalStorage<HistoryItem[]>(
    "exif_history",
    [],
  );
  const [showSettings, setShowSettings] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [isDragging, setIsDragging] = useState(false);

  // Pro Tools State
  const [legacyFeatures, setLegacyFeatures] = useState<LegacyFeatures>({
    fmts: [],
    args: [],
    configs: [],
  });
  const [activeTab, setActiveTab] = useState<"history" | "tools">("history");
  const [activeTool, setActiveTool] = useState<{
    type: "inspect" | "export" | "macro";
    value: string | null;
  }>({ type: "inspect", value: null });

  // Fetch Initial Data
  useEffect(() => {
    fetch("/api/version")
      .then((res) => res.json())
      .then((data) => setVersion(data.version || "Unknown"))
      .catch(() => setVersion("N/A"));

    fetch("/api/legacy/list")
      .then((res) => res.json())
      .then((data) => setLegacyFeatures(data))
      .catch((err) => console.error("Failed to load tools", err));
  }, []);

  const triggerSaveIndicator = () => {
    setSaving(true);
    setTimeout(() => setSaving(false), 2000);
  };

  const clearHistory = () => {
    setHistory([]);
    setMetadata(null);
    setOutputLog(null);
    setFile(null);
    setError(null);
    triggerSaveIndicator();
  };

  // --- Handlers ---

  const processFile = async (uploadedFile: File) => {
    setFile(uploadedFile);
    setMetadata(null);
    setOutputLog(null);
    setError(null);
    setLoading(true);

    const formData = new FormData();
    formData.append("file", uploadedFile);

    try {
      let response;
      let resultType = "json";

      // Router based on Active Tool
      if (activeTool.type === "inspect") {
        response = await fetch("/api/metadata", {
          method: "POST",
          body: formData,
        });
      } else if (activeTool.type === "export" && activeTool.value) {
        formData.append("format", activeTool.value.replace(".fmt", ""));
        response = await fetch("/api/export", {
          method: "POST",
          body: formData,
        });
        resultType = "text"; // Usually XML/KML
      } else if (activeTool.type === "macro" && activeTool.value) {
        formData.append("macro", activeTool.value);
        response = await fetch("/api/macro", {
          method: "POST",
          body: formData,
        });
        resultType = "text";
      } else {
        throw new Error("Invalid Tool Configuration");
      }

      if (!response.ok) {
        const errData = await response
          .json()
          .catch(() => ({ error: "Request Failed" }));
        throw new Error(errData.error || `Error ${response.status}`);
      }

      if (resultType === "json") {
        const data = await response.json();
        setMetadata(data);
        const newItem: HistoryItem = {
          id: crypto.randomUUID(),
          name: uploadedFile.name,
          timestamp: new Date().toLocaleTimeString(),
          metadata: data,
        };
        setHistory((prev) => [newItem, ...prev].slice(0, 15));
      } else {
        const text = await response.text();
        setOutputLog(text);
        // If export, maybe trigger download?
        if (activeTool.type === "export") {
          downloadBlob(
            text,
            `${uploadedFile.name}.${activeTool.value?.replace(".fmt", "")}`,
          );
        }
      }
      triggerSaveIndicator();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const downloadBlob = (content: string, filename: string) => {
    const blob = new Blob([content], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const handleFileUpload = (
    e: React.ChangeEvent<HTMLInputElement> | React.DragEvent<any>,
  ) => {
    setIsDragging(false);
    let uploadedFile: File | null = null;
    if ("target" in e && e.target && "files" in e.target && e.target.files) {
      uploadedFile = e.target.files[0];
    } else if ("dataTransfer" in e && e.dataTransfer.files) {
      uploadedFile = e.dataTransfer.files[0];
    }
    if (uploadedFile) processFile(uploadedFile);
  };

  // --- Helpers ---
  const getGPSData = () => {
    if (!metadata) return null;
    const lat = metadata.GPSLatitude;
    const lon = metadata.GPSLongitude;
    if (typeof lat === "number" && typeof lon === "number") {
      let decLat = metadata.GPSLatitudeRef === "S" ? -lat : lat;
      let decLon = metadata.GPSLongitudeRef === "W" ? -lon : lon;
      return {
        coords: `${decLat.toFixed(6)}, ${decLon.toFixed(6)}`,
        link: `https://www.google.com/maps?q=${decLat},${decLon}`,
      };
    }
    return null;
  };
  const gpsData = getGPSData();

  const filteredMetadata = metadata
    ? Object.entries(metadata).filter(
        ([key, val]) =>
          key.toLowerCase().includes(searchQuery.toLowerCase()) ||
          String(val).toLowerCase().includes(searchQuery.toLowerCase()),
      )
    : [];

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 font-sans selection:bg-indigo-500/30 overflow-x-hidden">
      {/* Dynamic Background */}
      <div className="fixed inset-0 pointer-events-none -z-10 bg-zinc-950">
        <div className="noise absolute inset-0" />
        <div
          className={`absolute top-[-20%] left-[-10%] w-[60%] h-[60%] blur-[160px] rounded-full animate-float transition-colors duration-1000 ${activeTool.type === "inspect" ? "bg-indigo-500/10" : activeTool.type === "export" ? "bg-emerald-500/10" : "bg-amber-500/10"}`}
        />
        <div
          className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-fuchsia-500/10 blur-[160px] rounded-full animate-float"
          style={{ animationDelay: "2s" }}
        />
      </div>

      <nav className="fixed top-0 left-0 right-0 z-40 bg-zinc-950/20 backdrop-blur-md border-b border-white/5 py-4 px-6 md:px-12">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="flex items-center gap-3"
          >
            <div
              className={`w-10 h-10 rounded-xl flex items-center justify-center shadow-lg transition-colors duration-500 ${activeTool.type === "inspect" ? "bg-linear-to-tr from-indigo-600 to-fuchsia-600 shadow-indigo-500/20" : activeTool.type === "export" ? "bg-linear-to-tr from-emerald-600 to-teal-600 shadow-emerald-500/20" : "bg-linear-to-tr from-amber-600 to-orange-600 shadow-amber-500/20"}`}
            >
              <Fingerprint className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight bg-linear-to-r from-white to-zinc-400 bg-clip-text text-transparent">
                ExifTool Architect
              </h1>
              <span className="text-[10px] uppercase tracking-[0.3em] text-zinc-500">
                v{version.split(" ")[0]}
              </span>
            </div>
          </motion.div>
          <div className="flex items-center gap-4">
            <AnimatePresence>
              {saving && (
                <motion.div
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0 }}
                  className="hidden md:flex items-center gap-2 text-xs text-emerald-400 bg-emerald-400/10 px-4 py-2 rounded-full border border-emerald-400/20"
                >
                  <ShieldCheck className="w-3 h-3 animate-pulse" /> Synced
                </motion.div>
              )}
            </AnimatePresence>
            <button
              onClick={() => setShowSettings(true)}
              className="p-3 rounded-2xl glass glass-hover group"
            >
              <Settings className="w-5 h-5 text-zinc-400 group-hover:rotate-90 transition-transform duration-500" />
            </button>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto pt-32 pb-12 px-6 grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
        {/* LEFT PANEL */}
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="lg:col-span-4 space-y-8"
        >
          {/* Smart Portal */}
          <motion.div variants={itemVariants} className="space-y-4">
            <h2
              className={`text-sm font-semibold uppercase tracking-widest ml-2 transition-colors ${activeTool.type === "inspect" ? "text-indigo-400/70" : activeTool.type === "export" ? "text-emerald-400/70" : "text-amber-400/70"}`}
            >
              {activeTool.type === "inspect"
                ? "Metadata Portal"
                : activeTool.type === "export"
                  ? `Export: ${activeTool.value}`
                  : `Macro: ${activeTool.value}`}
            </h2>
            <div
              onDragOver={(e) => {
                e.preventDefault();
                setIsDragging(true);
              }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={handleFileUpload}
              className={`relative overflow-hidden group aspect-square lg:aspect-video rounded-4xl flex items-center justify-center border-2 border-dashed transition-all duration-500 ${isDragging ? "border-indigo-500 scale-95" : "border-white/10 bg-white/2"}`}
            >
              <label className="relative z-10 flex flex-col items-center justify-center cursor-pointer w-full h-full p-8 text-center">
                <input
                  type="file"
                  className="hidden"
                  onChange={handleFileUpload}
                />
                <motion.div
                  animate={isDragging ? { y: -10 } : { y: 0 }}
                  className={`w-20 h-20 rounded-3xl flex items-center justify-center mb-6 shadow-2xl border border-white/5 transition-colors duration-500 ${activeTool.type === "inspect" ? "bg-zinc-900/80 text-indigo-400" : activeTool.type === "export" ? "bg-emerald-900/20 text-emerald-400" : "bg-amber-900/20 text-amber-400"}`}
                >
                  {activeTool.type === "inspect" ? (
                    <Upload className="w-10 h-10" />
                  ) : activeTool.type === "export" ? (
                    <Download className="w-10 h-10" />
                  ) : (
                    <Terminal className="w-10 h-10" />
                  )}
                </motion.div>
                <div className="space-y-1">
                  <h3 className="text-xl font-bold">
                    {activeTool.type === "inspect"
                      ? "Inject Media"
                      : `Drop to ${activeTool.type}`}
                  </h3>
                  <p className="text-zinc-500 text-sm">
                    Target: {activeTool.value || "Standard Analysis"}
                  </p>
                </div>
              </label>
            </div>
            {/* Active File Indicator - Restores usage of `file` state */}
            {file && !loading && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="p-3 bg-white/5 rounded-xl border border-white/10 flex items-center gap-3"
              >
                <div className="w-8 h-8 rounded-lg bg-zinc-900 flex items-center justify-center">
                  <ImageIcon className="w-4 h-4 text-zinc-500" />
                </div>
                <div className="flex-1 overflow-hidden">
                  <p className="text-xs font-bold truncate text-zinc-300">
                    {file.name}
                  </p>
                  <p className="text-[10px] text-zinc-500">
                    Ready for next action
                  </p>
                </div>
              </motion.div>
            )}

            {/* Error Banner - Restores usage of `error` state */}
            <AnimatePresence>
              {error && (
                <motion.div
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                  className="p-4 bg-rose-500/10 border border-rose-500/20 rounded-2xl flex gap-3 text-rose-400"
                >
                  <AlertCircle className="w-5 h-5 shrink-0" />
                  <div className="text-xs font-medium">{error}</div>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>

          {/* Command Center Tabs */}
          <div className="flex p-1 bg-white/5 rounded-2xl border border-white/5">
            <button
              onClick={() => setActiveTab("history")}
              className={`flex-1 py-2 rounded-xl text-xs font-bold uppercase tracking-widest transition-all ${activeTab === "history" ? "bg-zinc-800 text-white shadow-lg" : "text-zinc-500 hover:text-zinc-300"}`}
            >
              History
            </button>
            <button
              onClick={() => setActiveTab("tools")}
              className={`flex-1 py-2 rounded-xl text-xs font-bold uppercase tracking-widest transition-all ${activeTab === "tools" ? "bg-zinc-800 text-white shadow-lg" : "text-zinc-500 hover:text-zinc-300"}`}
            >
              Pro Tools
            </button>
          </div>

          <AnimatePresence mode="wait">
            {activeTab === "history" ? (
              <motion.section
                key="history"
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 10 }}
                className="space-y-3"
              >
                {history.length === 0 ? (
                  <div className="p-8 text-center rounded-3xl border border-dashed border-white/5 text-zinc-600 text-xs">
                    No records found.
                  </div>
                ) : (
                  history.map((item) => (
                    <div
                      key={item.id}
                      onClick={() => {
                        setMetadata(item.metadata);
                        setOutputLog(null);
                        setActiveTool({ type: "inspect", value: null });
                      }}
                      className="p-3 rounded-2xl glass glass-hover cursor-pointer flex items-center gap-3 group"
                    >
                      <div className="w-8 h-8 bg-zinc-900/50 rounded-lg flex items-center justify-center text-zinc-500 group-hover:text-indigo-400">
                        <ImageIcon className="w-4 h-4" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-bold truncate">
                          {item.name}
                        </p>
                        <p className="text-[10px] text-zinc-500">
                          {item.timestamp}
                        </p>
                      </div>
                    </div>
                  ))
                )}
              </motion.section>
            ) : (
              <motion.section
                key="tools"
                initial={{ opacity: 0, x: 10 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -10 }}
                className="space-y-6"
              >
                {/* Reset */}
                <button
                  onClick={() =>
                    setActiveTool({ type: "inspect", value: null })
                  }
                  className={`w-full p-4 rounded-2xl border flex items-center gap-3 transition-all ${activeTool.type === "inspect" ? "bg-indigo-500/10 border-indigo-500/50 text-indigo-400" : "bg-transparent border-white/5 text-zinc-400 hover:bg-white/5"}`}
                >
                  <ShieldCheck className="w-5 h-5" />
                  <div className="text-left">
                    <p className="text-xs font-black uppercase tracking-wider">
                      Standard Inspector
                    </p>
                    <p className="text-[10px] opacity-70">
                      JSON Metadata Extraction
                    </p>
                  </div>
                </button>

                {/* Exports */}
                <div className="space-y-2">
                  <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest ml-2">
                    Exports
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    {legacyFeatures.fmts.map((fmt) => (
                      <button
                        key={fmt}
                        onClick={() =>
                          setActiveTool({ type: "export", value: fmt })
                        }
                        className={`p-3 rounded-xl border text-left transition-all ${activeTool.type === "export" && activeTool.value === fmt ? "bg-emerald-500/10 border-emerald-500/50 text-emerald-400" : "bg-white/2 border-white/5 text-zinc-400 hover:bg-white/5"}`}
                      >
                        <MapIcon className="w-4 h-4 mb-2 opacity-50" />
                        <p className="text-[10px] font-bold uppercase truncate">
                          {fmt.replace(".fmt", "")}
                        </p>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Macros */}
                <div className="space-y-2">
                  <p className="text-[10px] font-bold text-zinc-600 uppercase tracking-widest ml-2">
                    Macros / Fixes
                  </p>
                  <div className="space-y-2">
                    {legacyFeatures.args.map((arg) => (
                      <button
                        key={arg}
                        onClick={() =>
                          setActiveTool({ type: "macro", value: arg })
                        }
                        className={`w-full p-3 rounded-xl border flex items-center gap-3 transition-all ${activeTool.type === "macro" && activeTool.value === arg ? "bg-amber-500/10 border-amber-500/50 text-amber-400" : "bg-white/2 border-white/5 text-zinc-400 hover:bg-white/5"}`}
                      >
                        <Terminal className="w-4 h-4 opacity-50" />
                        <p className="text-xs font-mono">
                          {arg.replace(".args", "")}
                        </p>
                      </button>
                    ))}
                  </div>
                </div>
              </motion.section>
            )}
          </AnimatePresence>
        </motion.div>

        {/* RIGHT PANEL (RESULTS) */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="lg:col-span-8 h-full"
        >
          <AnimatePresence mode="wait">
            {!metadata && !outputLog && !loading && (
              <div className="h-[600px] border-2 border-dashed border-white/5 rounded-4xl flex flex-col items-center justify-center gap-4 text-zinc-700">
                <Box className="w-12 h-12 opacity-20" />
                <p className="text-sm font-medium">
                  Select a tool and drop a file
                </p>
              </div>
            )}

            {loading && (
              <div className="h-[600px] glass rounded-4xl p-10 shimmer">
                <div className="w-1/3 h-8 bg-white/5 rounded-lg mb-8 animate-pulse" />
                <div className="space-y-4">
                  {[...Array(5)].map((_, i) => (
                    <div key={i} className="h-4 bg-white/5 rounded w-full" />
                  ))}
                </div>
              </div>
            )}

            {outputLog && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="h-[750px] glass rounded-4xl overflow-hidden p-8 flex flex-col relative"
              >
                {/* Fixed gradient-to-linear warning */}
                <div className="absolute top-0 left-0 right-0 h-1 bg-linear-to-r from-amber-500 to-orange-500" />
                <h2 className="text-xl font-bold mb-4 flex items-center gap-3 text-amber-400">
                  <Terminal className="w-6 h-6" /> Console Output
                </h2>
                <pre className="flex-1 bg-black/50 rounded-2xl p-6 font-mono text-xs text-emerald-400 overflow-auto border border-white/10 shadow-inner custom-scrollbar">
                  {outputLog}
                </pre>
                <div className="mt-4 flex justify-end">
                  <button
                    onClick={() => {
                      const b = new Blob([outputLog], { type: "text/plain" });
                      const u = URL.createObjectURL(b);
                      window.open(u);
                    }}
                    className="px-6 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-xs font-bold uppercase tracking-widest text-zinc-300"
                  >
                    Open Raw
                  </button>
                </div>
              </motion.div>
            )}

            {metadata && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="glass rounded-4xl overflow-hidden flex flex-col h-[750px] relative shadow-2xl"
              >
                <div className="p-8 border-b border-white/5 flex flex-col md:flex-row gap-6 justify-between bg-white/2 relative z-10">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 bg-emerald-500/10 rounded-2xl flex items-center justify-center border border-emerald-500/20">
                      <ShieldCheck className="w-8 h-8 text-emerald-500" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-black tracking-tight">
                        Metadata Feed
                      </h2>
                      <p className="text-xs font-mono text-zinc-500 mt-1 uppercase tracking-widest">
                        {Object.keys(metadata).length} Tags
                      </p>
                    </div>
                  </div>
                  <div className="relative">
                    <Search className="absolute left-4 top-3.5 w-4 h-4 text-zinc-500" />
                    <input
                      type="text"
                      placeholder="Search..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="bg-zinc-950/50 border border-white/5 rounded-2xl pl-11 pr-5 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 w-64"
                    />
                  </div>
                </div>

                <div className="flex-1 overflow-y-auto p-8 scrollbar-hide space-y-8">
                  {gpsData && (
                    <div className="p-6 rounded-3xl bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-between gap-6">
                      <div className="flex items-center gap-4">
                        <div className="p-3 bg-indigo-500/20 rounded-xl">
                          <MapPin className="w-6 h-6 text-indigo-400" />
                        </div>
                        <div>
                          <h3 className="text-lg font-bold">GPS Data</h3>
                          <p className="text-xs text-indigo-300 font-mono">
                            {gpsData.coords}
                          </p>
                        </div>
                      </div>
                      <a
                        href={gpsData.link}
                        target="_blank"
                        className="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 rounded-xl text-white text-xs font-black uppercase tracking-widest"
                      >
                        Satellite View
                      </a>
                    </div>
                  )}

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {filteredMetadata.length > 0 ? (
                      filteredMetadata.map(([k, v]) => (
                        <div
                          key={k}
                          className="p-4 rounded-2xl bg-white/2 border border-white/5 hover:border-indigo-500/30 transition-all"
                        >
                          <p className="text-[10px] font-black uppercase tracking-wider text-indigo-400/60 mb-1">
                            {k}
                          </p>
                          <div className="text-sm font-bold text-zinc-300 truncate">
                            {typeof v === "object"
                              ? JSON.stringify(v)
                              : String(v)}
                          </div>
                        </div>
                      ))
                    ) : (
                      <div className="col-span-full py-12 text-center text-zinc-600">
                        No results found
                      </div>
                    )}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </main>

      {/* Settings Panel Placeholder */}
      <AnimatePresence>
        {showSettings && (
          <motion.div
            initial={{ x: "100%" }}
            animate={{ x: 0 }}
            exit={{ x: "100%" }}
            className="fixed inset-y-0 right-0 w-96 bg-zinc-950/90 backdrop-blur-xl border-l border-white/10 z-50 p-8 shadow-2xl"
          >
            <div className="flex justify-between items-center mb-10">
              <h2 className="text-2xl font-black">Settings</h2>
              <button onClick={() => setShowSettings(false)}>
                <ArrowRight className="w-6 h-6 text-zinc-500" />
              </button>
            </div>
            <button
              onClick={clearHistory}
              className="w-full py-4 rounded-2xl bg-rose-500/10 text-rose-500 font-bold uppercase tracking-widest text-xs border border-rose-500/20 hover:bg-rose-500 hover:text-white transition-all"
            >
              Pure History
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
