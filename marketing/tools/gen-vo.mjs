// Generates the AuraBank promo voiceover, one file per line, via Edge neural TTS.
// Only the script text below is sent to Microsoft's read-aloud endpoint.
// Usage: node gen-vo.mjs <outDir> [voice]
import { MsEdgeTTS, OUTPUT_FORMAT } from "msedge-tts";
import { mkdirSync, renameSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";

const outDir = resolve(process.argv[2] ?? "../aurabank-promo/assets/vo/raw");
const voice = process.argv[3] ?? "en-US-AvaMultilingualNeural";

const lines = [
  { id: "vo1", text: "Meet Aura." },
  { id: "vo2", text: "Your whole bank, right in your pocket." },
  { id: "vo3", text: "On the web, transfers land in seconds." },
  { id: "vo4", text: "Every move screened by AI, and signed off by real people." },
  { id: "vo5", text: "Aura. Banking, in a new light." },
];

mkdirSync(outDir, { recursive: true });

for (const line of lines) {
  const tts = new MsEdgeTTS();
  await tts.setMetadata(voice, OUTPUT_FORMAT.AUDIO_24KHZ_96KBITRATE_MONO_MP3);
  const tmp = join(outDir, `${line.id}.tmp`);
  rmSync(tmp, { recursive: true, force: true });
  mkdirSync(tmp, { recursive: true });
  const { audioFilePath } = await tts.toFile(tmp, line.text, { rate: "+4%" });
  renameSync(audioFilePath, join(outDir, `${line.id}.mp3`));
  rmSync(tmp, { recursive: true, force: true });
  tts.close();
  console.log(`ok ${line.id} -> ${line.id}.mp3`);
}
