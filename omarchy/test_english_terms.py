import runpy
import unittest
from pathlib import Path


core = runpy.run_path(str(Path(__file__).with_name("whisper-core")))
normalize = core["normalize_english_terms"]


class EnglishTermsTests(unittest.TestCase):
    def test_common_product_names_use_english_spelling(self):
        text = "ส่งในดิสคอร์ด แล้วเปิดกิตฮับกับแชตจีพีที"
        self.assertEqual(
            normalize(text),
            "ส่งใน Discord แล้วเปิด GitHub กับ ChatGPT",
        )

    def test_common_tech_terms_use_english_spelling(self):
        text = "ดูยูทูบในกูเกิลโครม แล้วเปิดด็อกเกอร์"
        self.assertEqual(
            normalize(text),
            "ดู YouTube ใน Google Chrome แล้วเปิด Docker",
        )

    def test_ambiguous_thai_words_are_preserved(self):
        text = "ส่งลิงก์ออนไลน์ แล้วคุยเรื่องไลน์รถไฟ"
        self.assertEqual(normalize(text), text)


if __name__ == "__main__":
    unittest.main()
