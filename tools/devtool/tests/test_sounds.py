"""Sound loop settings in .import files."""

import unittest

from devtool import sounds

MP3 = '''[remap]

importer="mp3"
type="AudioStreamMP3"
path="res://.import/hum.mp3-0123.mp3str"

[deps]

source_file="res://assets/audio/hum.mp3"

[params]

loop=false
loop_offset=0
'''
WAV = '''[remap]

importer="wav"
path="res://.import/zap.wav-abcd.sample"

[params]

force/8_bit=false
edit/loop_mode=0
edit/loop_begin=0
'''


class SoundsTest(unittest.TestCase):
    def test_the_loop_setting_is_set_in_place(self):
        self.assertEqual(sounds.set_loop(MP3, ".mp3", True), MP3.replace("loop=false", "loop=true"))
        self.assertEqual(sounds.set_loop(WAV, ".wav", True), WAV.replace("edit/loop_mode=0", "edit/loop_mode=1"))
        self.assertEqual(sounds.set_loop(WAV, ".WAV", False), WAV)

    def test_a_missing_setting_is_added(self):
        bare = WAV.replace("edit/loop_mode=0\n", "")
        self.assertIn("[params]\n\nedit/loop_mode=1\nforce/8_bit=false", sounds.set_loop(bare, ".wav", True))
        self.assertTrue(sounds.set_loop("[remap]\n", ".ogg", True).endswith("[params]\n\nloop=true\n"))

    def test_which_slots_are_wrong_and_where_godot_keeps_the_import(self):
        slots = [{"slot": "a", "kind": "loop", "path": "res://a.wav", "loops": False},
                 {"slot": "b", "kind": "world", "path": "res://b.wav", "loops": False},
                 {"slot": "c", "kind": "loop", "path": "", "loops": False}]
        self.assertEqual([slot["slot"] for slot in sounds.wrong_slots(slots)], ["a"])
        self.assertTrue(sounds.imported_md5(MP3).endswith("/.import/hum.mp3-0123.md5"))
