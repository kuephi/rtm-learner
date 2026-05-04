"""Tests for exporters/pleco.py — all pure functions, no mocking needed."""
from domain.models import Episode, VocabEntry
from exporters.pleco import _clean, _card_line, generate_pleco_file


def _make_entry(**kwargs) -> VocabEntry:
    defaults = dict(type="priority", number=1, chinese="", pinyin="", english="",
                    german="", example_zh="", example_en="", example_de="")
    return VocabEntry(**{**defaults, **kwargs})


def _make_episode(**kwargs) -> Episode:
    defaults = dict(episode=1, title="Test", url="", pub_date="", words=[], idioms=[])
    return Episode(**{**defaults, **kwargs})


class TestClean:
    def test_removes_escaped_quotes(self):
        assert _clean('\\"hello\\"') == '"hello"'

    def test_normalizes_left_right_double_quotes(self):
        assert _clean("“hello”") == '"hello"'
        assert _clean("„hello“") == '"hello"'

    def test_normalizes_curly_single_quotes(self):
        assert _clean("‘it’s fine") == "'it's fine"

    def test_leaves_plain_strings_untouched(self):
        assert _clean("plain text") == "plain text"

    def test_empty_string(self):
        assert _clean("") == ""


class TestCardLine:
    def test_formats_all_fields(self):
        entry = _make_entry(chinese="测试", pinyin="cè shì", german="Test",
                            example_zh="这是测试", example_de="Das ist ein Test")
        assert _card_line(entry) == "测试\tcè shì\tTest | 这是测试 Das ist ein Test"

    def test_falls_back_to_english_when_no_german(self):
        entry = _make_entry(chinese="测试", pinyin="cè shì", english="test")
        assert _card_line(entry) == "测试\tcè shì\ttest"

    def test_example_zh_without_example_de(self):
        entry = _make_entry(chinese="好", pinyin="hǎo", german="gut", example_zh="你好")
        assert _card_line(entry) == "好\thǎo\tgut | 你好"

    def test_no_example_fields(self):
        entry = _make_entry(chinese="好", pinyin="hǎo", german="gut")
        assert _card_line(entry) == "好\thǎo\tgut"

    def test_missing_fields_default_to_empty(self):
        line = _card_line(_make_entry())
        assert line == "\t\t"


class TestGeneratePlecoFile:
    def test_creates_file_with_header(self, tmp_path):
        episode = _make_episode(episode=265, title="#265[中级]: Test Topic")
        out = tmp_path / "265_pleco.txt"
        generate_pleco_file(episode, out)
        assert out.exists()
        assert "// RTM #265:" in out.read_text(encoding="utf-8")

    def test_strips_episode_prefix_from_title(self, tmp_path):
        episode = _make_episode(episode=1, title="#1[中级]: My Topic")
        out = tmp_path / "1_pleco.txt"
        generate_pleco_file(episode, out)
        content = out.read_text(encoding="utf-8")
        assert "// RTM #1: My Topic" in content

    def test_writes_word_cards(self, tmp_path):
        word = _make_entry(chinese="你好", pinyin="nǐ hǎo", german="Hallo")
        episode = _make_episode(episode=1, words=[word])
        out = tmp_path / "1_pleco.txt"
        generate_pleco_file(episode, out)
        assert "你好\tnǐ hǎo\tHallo" in out.read_text(encoding="utf-8")

    def test_words_and_idioms_combined(self, tmp_path):
        word = _make_entry(chinese="测试", pinyin="cè shì", german="Test")
        idiom = _make_entry(chinese="无懈可击", pinyin="wú xiè kě jī", german="einwandfrei")
        episode = _make_episode(episode=1, words=[word], idioms=[idiom])
        out = tmp_path / "1_pleco.txt"
        generate_pleco_file(episode, out)
        content = out.read_text(encoding="utf-8")
        assert "测试" in content
        assert "无懈可击" in content

    def test_creates_parent_directory(self, tmp_path):
        episode = _make_episode()
        out = tmp_path / "nested" / "dir" / "1_pleco.txt"
        generate_pleco_file(episode, out)
        assert out.exists()

    def test_returns_output_path(self, tmp_path):
        episode = _make_episode()
        out = tmp_path / "1_pleco.txt"
        result = generate_pleco_file(episode, out)
        assert result == out
