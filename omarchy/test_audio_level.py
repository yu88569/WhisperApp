import array
import os
import runpy
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch


core = runpy.run_path(str(Path(__file__).with_name("whisper-core")))
read_level = core["read_recent_audio_level"]


class AudioLevelTests(unittest.TestCase):
    def test_speech_changes_level_and_silence_lowers_it(self):
        with tempfile.TemporaryDirectory() as directory:
            recording = Path(directory) / "recording.wav"
            recording.write_bytes(b"\0" * 44)
            last_size, level = read_level(recording, 0)
            self.assertEqual(level, 0.0)

            with recording.open("ab") as audio:
                audio.write(array.array("h", [1800] * 4800).tobytes())
            last_size, level = read_level(recording, last_size)
            self.assertGreater(level, 0.4)

            with recording.open("ab") as audio:
                audio.write(array.array("h", [0] * 4800).tobytes())
            last_size, level = read_level(recording, last_size)
            self.assertEqual(level, 0.0)
            self.assertEqual(read_level(recording, last_size)[1], 0.0)

    def test_level_stays_bounded_for_loud_audio(self):
        with tempfile.TemporaryDirectory() as directory:
            recording = Path(directory) / "recording.wav"
            recording.write_bytes(b"\0" * 44 + array.array("h", [30000] * 4800).tobytes())
            _, level = read_level(recording, 0)
            self.assertEqual(level, 1.0)

    def test_meter_publishes_new_audio_and_stops_with_recording(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            recording = base / "recording.wav"
            recording.write_bytes(b"\0" * 44)
            pid_file = base / "record.pid"
            pid_file.write_text(str(os.getpid()))
            level_file = base / "level.txt"
            meter = core["run_level_meter"]
            with patch.dict(meter.__globals__, {
                "TEMP_WAV": recording,
                "PID_FILE": pid_file,
                "LEVEL_FILE": level_file,
                "STATE_DIR": base,
            }):
                thread = threading.Thread(target=meter, args=(os.getpid(),), daemon=True)
                thread.start()
                try:
                    with recording.open("ab") as audio:
                        audio.write(array.array("h", [1800] * 4800).tobytes())
                    deadline = time.monotonic() + 2
                    while time.monotonic() < deadline:
                        if level_file.exists() and float(level_file.read_text()) > 0.4:
                            break
                        time.sleep(0.02)
                    else:
                        self.fail("meter did not publish the new audio level")
                finally:
                    pid_file.unlink()
                    thread.join(timeout=2)
                self.assertFalse(thread.is_alive())


if __name__ == "__main__":
    unittest.main()
