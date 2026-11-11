# Claude Code দিয়ে ভিডিও বানানোর প্রম্পট

## কীভাবে ব্যবহার করবেন

1. এই রিপো (`Expense-Trackers`) খোলা অবস্থায় Claude Code চালু করুন — কম্পিউটারে অথবা claude.ai/code-এ।
   কম্পিউটারে হলে Node.js 18 বা তার পরের ভার্সন লাগবে।
2. ভয়েস রেকর্ড করে থাকলে `s01.mp3` … `s10.mp3` ফাইলগুলো `video/public/voice/` ফোল্ডারে রাখুন।
   ব্যাকগ্রাউন্ড মিউজিক চাইলে `video/public/music.mp3` রাখুন। কপিরাইট-মুক্ত মিউজিক ব্যবহার করবেন।
   ভয়েস বা মিউজিক না থাকলেও ভিডিও তৈরি হবে; পরে দিলে শুধু আবার render করলেই হবে।
3. নিচের বক্সের পুরো লেখা কপি করে Claude Code-এ পেস্ট করুন।
4. শেষে MP4 পাবেন `video/out/takar-khata-reel.mp4`-এ।

> ভিডিও বানানো হবে [Remotion](https://www.remotion.dev) দিয়ে। একক ব্যক্তি বা ছোট দলের জন্য এটা বিনামূল্যে; বড় কোম্পানির জন্য লাইসেন্স লাগে।

---

```text
Build a 56-second vertical promo video for the "টাকার খাতা" (Takar Khata) Android app using Remotion, and render it to an MP4.

## Source material (read these first)
- docs/video/script.md — the source of truth: 10 scenes with exact frame ranges, Bangla voiceover lines, on-screen Bangla text, and what each scene shows. Follow its scene order, timing and wording exactly; do not rewrite or translate the Bangla text.
- docs/screenshots/*.png — real app screenshots, each 823×1783 (a full phone screen). Use only the files the script names for each scene.
- assets/images/logo-512.png (app logo), assets/images/developer.jpg (developer photo for the final scene).
- Brand colours: navy #23308C (main background), yellow #FFCF4A (accent), expense #E5533D, income #2E9E5B, debt #7E57C2.

## Output
- A Remotion project in a new `video/` folder at the repo root. Do not modify anything outside `video/` except adding `video/node_modules`, `video/out` and `video/.remotion` to the root .gitignore.
- One composition, id `TakarKhataReel`: 1080×1920, 30 fps, 1680 frames.
- Rendered file: video/out/takar-khata-reel.mp4 (H.264).
- Copy the screenshots, logo and developer photo into video/public/ so the project is self-contained.

## Requirements
- Bangla text must render with correct conjuncts and vowel signs (e.g. "ক্যাটাগরি", "স্বাস্থ্য"). Load a Bengali web font through @remotion/google-fonts. Prefer "Hind Siliguri"; fall back to "Noto Sans Bengali". Apply it to every text element, because a missing font silently falls back to boxes or broken shaping.
- Show screenshots inside a simple phone mockup built in CSS: rounded dark bezel, slight shadow, about 640px wide. Screenshots are taller than the frame shows, so pan or zoom across them slowly where the script asks for it (Ken Burns style) rather than shrinking them to fit.
- Captions: bold, at least 56px, white or yellow on a soft dark pill, at most 2 lines. Keep every caption and important visual between y=220 and y=1500, because Reels/Shorts overlay their own buttons and text on the top and bottom edges.
- Motion: use spring()/interpolate for entrances, with short (8–12 frame) transitions between scenes. Keep it lively but readable: each caption must stay fully visible for at least 1.5 seconds.
- Audio:
  - If video/public/voice/sNN.mp3 exists, play it from the start of scene NN.
  - If video/public/music.mp3 exists, loop it under everything at about 0.15 volume, raised to about 0.35 when no voice is playing, with a 1-second fade-out at the end.
  - Detect file presence at build time (for example with a small script that writes a manifest the composition imports), so the render succeeds with no audio files at all.
- Structure: one React component per scene, plus shared components (PhoneFrame, Caption, Badge/Chip), so a single scene can be adjusted later without touching the rest.

## Setup
- Use the current stable Remotion release from npm. Check installed APIs against the package's own types and docs rather than assuming signatures from memory, since Remotion's API changes between majors.
- Keep dependencies minimal: remotion, @remotion/cli, @remotion/google-fonts, react, react-dom, typescript.

## Verify before finishing
1. Run a type check, then render one still per scene at its midpoint (npx remotion still). Open each still and check:
   - Bangla text is correctly shaped, with no boxes and no detached vowel signs.
   - Nothing overflows the safe area.
   - The right screenshot appears in each scene.
   Fix any problem and re-render that still.
2. Render the full MP4 and confirm its duration (56 s), resolution (1080×1920) and that it plays.
3. Report: the output path, the file size, which audio files were found and used, and anything from the script you could not do exactly as written.

If you commit, commit as `mukit <abdullahalmukit287@gmail.com>` with no co-author trailer.
```
