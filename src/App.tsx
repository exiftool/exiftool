import React, { useState, useEffect } from "react";
import {
  Upload,
  Image as ImageIcon,
  Settings,
  Trash2,
  CheckCircle2,
  Cloud,
  Zap,
  ShieldCheck,
  AlertCircle,
  FileCode,
  ArrowRight,
  Fingerprint,
  HardDrive,
  Search,
  MapPin,
  ExternalLink,
  Copy,
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

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1,
    },
  },
};

const itemVariants = {
  hidden: { y: 20, opacity: 0 },
  visible: { y: 0, opacity: 1 },
};

export default function App() {
  const [file, setFile] = useState<File | null>(null);
  const [metadata, setMetadata] = useState<Metadata | null>(null);
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

  // Fetch ExifTool Version
  useEffect(() => {
    fetch("/api/version")
      .then((res) => res.json())
      .then((data) => setVersion(data.version || "Unknown"))
      .catch(() => setVersion("N/A"));
  }, []);

  const handleFileUpload = async (
    e: React.ChangeEvent<HTMLInputElement> | React.DragEvent<any>,
  ) => {
    setIsDragging(false);
    let uploadedFile: File | null = null;

    if ("target" in e && e.target && "files" in e.target && e.target.files) {
      uploadedFile = e.target.files[0];
    } else if ("dataTransfer" in e && e.dataTransfer.files) {
      uploadedFile = e.dataTransfer.files[0];
    }

    if (!uploadedFile) return;

    setFile(uploadedFile);
    setMetadata(null);
    setError(null);
    setLoading(true);

    const formData = new FormData();
    formData.append("file", uploadedFile);

    try {
      const response = await fetch("/api/metadata", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || "Failed to extract metadata");
      }

      const data = await response.json();
      setMetadata(data);

      const newItem: HistoryItem = {
        id: crypto.randomUUID(),
        name: uploadedFile.name,
        timestamp: new Date().toLocaleTimeString(),
        metadata: data,
      };

      setHistory((prev: HistoryItem[]) => [newItem, ...prev].slice(0, 15));
      triggerSaveIndicator();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const triggerSaveIndicator = () => {
    setSaving(true);
    setTimeout(() => setSaving(false), 2000);
  };

  const clearHistory = () => {
    setHistory([]);
    setMetadata(null);
    setFile(null);
    setError(null);
    triggerSaveIndicator();
  };

  const filteredMetadata = metadata
    ? Object.entries(metadata).filter(
        ([key, val]) =>
          key.toLowerCase().includes(searchQuery.toLowerCase()) ||
          String(val).toLowerCase().includes(searchQuery.toLowerCase()),
      )
    : [];

  const getGPSData = () => {
    if (!metadata) return null;

    // Check for decimal coordinates (preferred)
    const lat = metadata.GPSLatitude;
    const lon = metadata.GPSLongitude;
    const latRef = metadata.GPSLatitudeRef;
    const lonRef = metadata.GPSLongitudeRef;

    if (typeof lat === "number" && typeof lon === "number") {
      let decLat = lat;
      let decLon = lon;
      if (latRef === "S") decLat *= -1;
      if (lonRef === "W") decLon *= -1;
      const coords = `${decLat.toFixed(6)}, ${decLon.toFixed(6)}`;
      return {
        coords,
        link: `https://www.google.com/maps?q=${decLat},${decLon}`,
      };
    }

    // Check for "GPSPosition" (e.g., "40.7128 N, 74.0060 W")
    if (metadata.GPSPosition) {
      const pos = String(metadata.GPSPosition);
      return {
        coords: pos,
        link: `https://www.google.com/maps?q=${encodeURIComponent(pos)}`,
      };
    }

    // Check for "GPS::Latitude" etc. (XMP/EXIF variations)
    const rawLat = metadata["GPS:GPSLatitude"] || metadata.GPSLatitude;
    const rawLon = metadata["GPS:GPSLongitude"] || metadata.GPSLongitude;
    if (rawLat && rawLon) {
      return {
        coords: `${rawLat} ${metadata.GPSLatitudeRef || ""}, ${rawLon} ${metadata.GPSLongitudeRef || ""}`,
        link: `https://www.google.com/maps?q=${encodeURIComponent(String(rawLat))} ${metadata.GPSLatitudeRef || ""},${encodeURIComponent(String(rawLon))} ${metadata.GPSLongitudeRef || ""}`,
      };
    }

    return null;
  };

  const gpsData = getGPSData();

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    triggerSaveIndicator(); // Reuse indicator for feedback
  };

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 font-sans selection:bg-indigo-500/30 overflow-x-hidden">
      {/* Background Aesthetic */}
      <div className="fixed inset-0 pointer-events-none -z-10 bg-zinc-950">
        <div className="noise absolute inset-0" />
        <div className="absolute top-[-20%] left-[-10%] w-[60%] h-[60%] bg-indigo-500/10 blur-[160px] rounded-full animate-float" />
        <div
          className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-fuchsia-500/10 blur-[160px] rounded-full animate-float"
          style={{ animationDelay: "2s" }}
        />
      </div>

      <nav className="fixed top-0 left-0 right-0 z-40 bg-zinc-950/20 backdrop-blur-md border-b border-white/5 py-4 px-6 md:px-12">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="flex items-center gap-3"
          >
            <div className="w-10 h-10 bg-linear-to-tr from-indigo-600 to-fuchsia-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-500/20 glow-indigo">
              <Fingerprint className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight bg-linear-to-r from-white to-zinc-400 bg-clip-text text-transparent text-glow">
                ExifTool Architect
              </h1>
              <span className="text-[10px] uppercase tracking-[0.3em] text-zinc-500 leading-none">
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
                  exit={{ opacity: 0, x: 20 }}
                  className="hidden md:flex items-center gap-2 text-xs text-emerald-400 bg-emerald-400/10 px-4 py-2 rounded-full border border-emerald-400/20"
                >
                  <CheckCircle2 className="w-3 h-3 animate-pulse" />
                  Synced
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
        {/* Left Section: Controls */}
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="lg:col-span-4 space-y-8"
        >
          {/* Hero Upload Segment */}
          <motion.div variants={itemVariants} className="space-y-4">
            <h2 className="text-sm font-semibold uppercase tracking-widest text-indigo-400/70 ml-2">
              Portal
            </h2>
            <div
              onDragOver={(e) => {
                e.preventDefault();
                setIsDragging(true);
              }}
              onDragLeave={() => setIsDragging(false)}
              onDrop={handleFileUpload}
              className={`relative overflow-hidden group aspect-square lg:aspect-video rounded-4xl flex items-center justify-center border-2 border-dashed transition-all duration-500 ${
                isDragging
                  ? "border-indigo-500 bg-indigo-500/10 scale-95"
                  : "border-white/10 bg-white/2"
              }`}
            >
              <div className="absolute inset-0 bg-linear-to-br from-indigo-500/5 to-fuchsia-500/5 opacity-0 group-hover:opacity-100 transition-opacity" />

              <label className="relative z-10 flex flex-col items-center justify-center cursor-pointer w-full h-full p-8 text-center">
                <input
                  type="file"
                  className="hidden"
                  onChange={handleFileUpload}
                />
                <motion.div
                  animate={isDragging ? { y: -10 } : { y: 0 }}
                  className="w-20 h-20 bg-zinc-900/80 rounded-3xl flex items-center justify-center mb-6 shadow-2xl border border-white/5 group-hover:scale-110 group-hover:glow-indigo transition-all duration-500"
                >
                  <Upload className="w-10 h-10 text-indigo-400" />
                </motion.div>
                <div className="space-y-1">
                  <h3 className="text-xl font-bold">Inject Media</h3>
                  <p className="text-zinc-500 text-sm">
                    Drop file or click to choose
                  </p>
                </div>
              </label>
            </div>
          </motion.div>

          {/* Active File Card */}
          <AnimatePresence>
            {file && !loading && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                className="p-6 rounded-4xl glass glow-indigo border-indigo-500/30 flex items-center gap-5 relative overflow-hidden"
              >
                <div className="absolute top-0 right-0 w-24 h-24 bg-indigo-500/5 blur-3xl -z-10" />
                <div className="p-3 bg-indigo-500/20 rounded-2xl">
                  <FileCode className="w-6 h-6 text-indigo-400" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-[10px] font-bold text-indigo-400 uppercase tracking-widest mb-1">
                    In Processing
                  </p>
                  <p className="text-lg font-bold truncate text-zinc-100">
                    {file.name}
                  </p>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Error Banner */}
          <AnimatePresence>
            {error && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="p-6 rounded-4xl bg-rose-500/10 border border-rose-500/30 flex items-start gap-4 glow-fuchsia"
              >
                <AlertCircle className="w-6 h-6 text-rose-500 shrink-0" />
                <div className="space-y-1">
                  <p className="text-sm font-bold text-rose-400 uppercase tracking-tight">
                    Access Denied
                  </p>
                  <p className="text-xs text-rose-500/70 leading-relaxed font-medium">
                    {error}
                  </p>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Recent History */}
          <motion.section variants={itemVariants} className="space-y-4">
            <div className="flex items-center justify-between px-2">
              <h2 className="text-sm font-semibold uppercase tracking-widest text-zinc-500">
                History
              </h2>
              <HardDrive className="w-4 h-4 text-zinc-700" />
            </div>

            <div className="space-y-3">
              {history.length === 0 ? (
                <div className="p-12 text-center rounded-4xl border-2 border-dashed border-white/5 text-zinc-600 text-sm font-medium">
                  Memory Empty
                </div>
              ) : (
                history.map((item: HistoryItem) => (
                  <motion.div
                    key={item.id}
                    layoutId={item.id}
                    whileHover={{ x: 5 }}
                    onClick={() => {
                      setMetadata(item.metadata);
                      setFile(null);
                      setError(null);
                    }}
                    className="p-4 rounded-2xl glass glass-hover cursor-pointer border-white/5 flex items-center gap-4 group"
                  >
                    <div className="w-10 h-10 bg-zinc-900 rounded-xl flex items-center justify-center group-hover:bg-indigo-500/20 transition-all duration-500">
                      <ImageIcon className="w-5 h-5 text-zinc-500 group-hover:text-indigo-400" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-bold truncate">{item.name}</p>
                      <p className="text-[10px] text-zinc-500 font-mono">
                        {item.timestamp}
                      </p>
                    </div>
                    <ArrowRight className="w-4 h-4 text-zinc-800 group-hover:text-indigo-400 transition-all" />
                  </motion.div>
                ))
              )}
            </div>
          </motion.section>
        </motion.div>

        {/* Right Section: Results */}
        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          className="lg:col-span-8 h-full"
        >
          <AnimatePresence mode="wait">
            {!metadata && !loading && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="h-[600px] border-2 border-dashed border-white/5 rounded-4xl flex flex-col items-center justify-center space-y-6 bg-white/1"
              >
                <div className="w-24 h-24 bg-zinc-900/50 rounded-4xl flex items-center justify-center shadow-inner">
                  <Cloud className="w-10 h-10 text-zinc-700 animate-pulse" />
                </div>
                <div className="text-center group">
                  <p className="text-xl font-bold bg-linear-to-b from-zinc-300 to-zinc-600 bg-clip-text text-transparent group-hover:from-white group-hover:to-zinc-300 transition-all">
                    Ready for Integration
                  </p>
                  <p className="text-zinc-600 text-xs mt-2 font-medium tracking-wide">
                    Waiting for media input...
                  </p>
                </div>
              </motion.div>
            )}

            {loading && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="h-[700px] glass rounded-4xl p-10 space-y-10 shimmer relative overflow-hidden"
              >
                <div className="flex items-center gap-8 animate-pulse">
                  <div className="w-32 h-32 bg-zinc-800/80 rounded-4xl" />
                  <div className="flex-1 space-y-4">
                    <div className="h-8 w-[50%] bg-zinc-800/80 rounded-xl" />
                    <div className="h-5 w-[70%] bg-zinc-800/80 rounded-xl" />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-8">
                  {[...Array(6)].map((_, i) => (
                    <div key={i} className="h-24 bg-zinc-800/40 rounded-3xl" />
                  ))}
                </div>
              </motion.div>
            )}

            {metadata && (
              <motion.div
                initial={{ opacity: 0, scale: 0.98 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.98 }}
                className="glass rounded-4xl overflow-hidden flex flex-col h-[750px] relative shadow-2xl"
              >
                {/* Visual Header */}
                <div className="p-8 border-b border-white/5 flex flex-col md:flex-row md:items-center justify-between gap-6 bg-white/2 relative z-10">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 bg-emerald-500/10 rounded-2xl flex items-center justify-center border border-emerald-500/20">
                      <ShieldCheck className="w-8 h-8 text-emerald-500" />
                    </div>
                    <div>
                      <h2 className="text-2xl font-black tracking-tight">
                        Metadata Feed
                      </h2>
                      <p className="text-xs font-mono text-zinc-500 mt-1 uppercase tracking-widest">
                        {Object.keys(metadata).length} Vectors Found
                      </p>
                    </div>
                  </div>
                  <div className="relative group">
                    <div className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500 flex items-center justify-center group-focus-within:text-indigo-400 transition-colors">
                      <Search className="w-4 h-4" />
                    </div>
                    <input
                      type="text"
                      placeholder="Search vectors..."
                      value={searchQuery}
                      onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                        setSearchQuery(e.target.value)
                      }
                      className="bg-zinc-950/50 border border-white/5 rounded-2xl pl-11 pr-5 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 transition-all w-full md:w-72 font-medium"
                    />
                  </div>
                </div>

                {/* Grid View */}
                <div className="flex-1 overflow-y-auto p-8 scrollbar-hide space-y-8">
                  {/* GPS Locator Section */}
                  {gpsData && (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="p-8 rounded-4xl bg-indigo-500/10 border border-indigo-500/30 flex flex-col md:flex-row items-center justify-between gap-8 glow-indigo relative overflow-hidden group"
                    >
                      <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/5 blur-3xl -z-10 group-hover:bg-indigo-500/10 transition-all" />

                      <div className="flex items-center gap-6">
                        <div className="w-20 h-20 bg-indigo-500/20 rounded-3xl flex items-center justify-center shadow-xl border border-indigo-500/20 group-hover:scale-105 transition-transform duration-500">
                          <MapPin className="w-10 h-10 text-indigo-400" />
                        </div>
                        <div className="space-y-2">
                          <h3 className="text-xl font-black tracking-tight">
                            GPS Locator
                          </h3>
                          <div className="flex items-center gap-3">
                            <p className="text-sm font-bold text-indigo-300 font-mono">
                              {gpsData.coords}
                            </p>
                            <button
                              onClick={() => copyToClipboard(gpsData.coords)}
                              className="p-1.5 rounded-lg hover:bg-indigo-500/20 text-indigo-400/50 hover:text-indigo-400 transition-all"
                              title="Copy Coordinates"
                            >
                              <Copy className="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center gap-4 w-full md:w-auto">
                        <a
                          href={gpsData.link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex-1 md:flex-none flex items-center justify-center gap-3 px-8 py-4 bg-indigo-600 hover:bg-indigo-500 rounded-2xl text-white text-sm font-black uppercase tracking-widest transition-all shadow-lg shadow-indigo-600/25"
                        >
                          Satellite View <ExternalLink className="w-4 h-4" />
                        </a>
                      </div>
                    </motion.div>
                  )}

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {filteredMetadata.length > 0 ? (
                      filteredMetadata.map(([key, value]) => (
                        <motion.div
                          key={key}
                          initial={{ opacity: 0, scale: 0.95 }}
                          animate={{ opacity: 1, scale: 1 }}
                          className="group p-5 rounded-2xl bg-white/2 border border-white/5 hover:border-indigo-500/30 transition-all duration-300"
                        >
                          <p className="text-[10px] font-black uppercase tracking-[0.2em] text-indigo-400/60 mb-2 group-hover:text-indigo-400 transition-colors">
                            {key}
                          </p>
                          <div className="text-sm font-bold text-zinc-300 group-hover:text-white transition-colors overflow-hidden text-ellipsis whitespace-nowrap md:whitespace-normal">
                            {typeof value === "object" ? (
                              <pre className="text-[10px] mt-2 p-2 bg-black/40 rounded-lg overflow-x-auto border border-white/5">
                                {JSON.stringify(value, null, 2)}
                              </pre>
                            ) : (
                              String(value)
                            )}
                          </div>
                        </motion.div>
                      ))
                    ) : (
                      <div className="col-span-full flex flex-col items-center justify-center h-[300px] text-zinc-600 grayscale">
                        <div className="w-16 h-16 mb-4 opacity-20 flex items-center justify-center">
                          <Search className="w-12 h-12" />
                        </div>
                        <p className="text-lg font-bold">
                          No results found in data stream
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </main>

      {/* Settings Panel (Drawer Style) */}
      <AnimatePresence>
        {showSettings && (
          <div className="fixed inset-0 z-100 flex justify-end">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="absolute inset-0 bg-zinc-950/60 backdrop-blur-sm"
              onClick={() => setShowSettings(false)}
            />
            <motion.div
              initial={{ x: "100%" }}
              animate={{ x: 0 }}
              exit={{ x: "100%" }}
              transition={{ type: "spring", damping: 25, stiffness: 200 }}
              className="relative w-full max-w-sm h-full bg-zinc-950/80 backdrop-blur-2xl border-l border-white/5 p-12 flex flex-col shadow-[-20px_0_40px_rgba(0,0,0,0.5)]"
            >
              <div className="flex items-center justify-between mb-12">
                <h2 className="text-3xl font-black">System</h2>
                <button
                  onClick={() => setShowSettings(false)}
                  className="p-2 text-zinc-500 hover:text-white transition-colors"
                >
                  <ArrowRight className="w-6 h-6" />
                </button>
              </div>

              <div className="space-y-8 flex-1">
                <div className="space-y-3">
                  <p className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest pl-1">
                    ExifTool Core
                  </p>
                  <div className="p-5 rounded-3xl glass border-white/10 flex items-center justify-between shadow-2xl">
                    <div className="flex items-center gap-4">
                      <div className="p-3 bg-indigo-500/10 rounded-2xl text-indigo-400">
                        <Zap className="w-5 h-5" />
                      </div>
                      <span className="text-sm font-bold">Version</span>
                    </div>
                    <span className="text-xs font-black bg-white/5 px-3 py-1.5 rounded-lg border border-white/10">
                      {version.split(" ")[0]}
                    </span>
                  </div>
                </div>

                <div className="space-y-3">
                  <p className="text-[10px] font-bold text-zinc-500 uppercase tracking-widest pl-1">
                    Data Storage
                  </p>
                  <div className="p-8 rounded-4xl glass border-rose-500/20 space-y-6 relative overflow-hidden group">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-rose-500/10 blur-3xl -z-10 group-hover:bg-rose-500/20 transition-all" />
                    <div className="flex items-center gap-4">
                      <Trash2 className="w-6 h-6 text-rose-500" />
                      <span className="text-sm font-bold">Flush Database</span>
                    </div>
                    <p className="text-xs text-zinc-500 font-medium font-mono leading-relaxed">
                      THIS ACTION WILL WIPE ALL LOCAL ACTIVITY RECORDS
                      INSTANTLY.
                    </p>
                    <button
                      onClick={() => {
                        clearHistory();
                        setShowSettings(false);
                      }}
                      className="w-full py-4 rounded-2xl bg-rose-500/10 hover:bg-rose-500 text-rose-500 hover:text-white text-xs font-black uppercase tracking-widest transition-all duration-300 border border-rose-500/30"
                    >
                      Purge History
                    </button>
                  </div>
                </div>
              </div>

              <div className="mt-auto opacity-20 text-[10px] font-black uppercase tracking-[0.4em] text-center">
                Deepmind Architect © 2026
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      <footer className="max-w-7xl mx-auto py-12 px-6 flex flex-col md:flex-row items-center justify-between border-t border-white/5 gap-6">
        <div className="flex items-center gap-2 opacity-30 group cursor-default">
          <Fingerprint className="w-4 h-4 group-hover:text-indigo-400 transition-colors" />
          <p className="text-[10px] uppercase font-black tracking-widest">
            Architect Core v1.0.4
          </p>
        </div>
        <p className="text-[10px] uppercase font-black tracking-[0.5em] opacity-10">
          Premium Local-First Architecture
        </p>
      </footer>
    </div>
  );
}
