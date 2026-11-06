"""
src/autoload/Constants.gd as data: its sections (the "# ===" headers), and in each its constants,
with the comment after each and the comment lines above it. A value is changed in place: only its
own text changes, its comments stay, and the file is otherwise byte for byte as it was. Godot
checks the new script parses before it is saved (the bridge's check_script).

    entries = parse(text); text = set_value(text, entries[0], "2.0")
"""

import re

PATH = "src/autoload/Constants.gd"
CONST = re.compile(r"^const\s+(\w+)\s*(?::\s*(\w+))?\s*:?=\s*")
HEADER_RULE = "# ====="
OPENERS, CLOSERS = "([{", ")]}"
FAMILIES = ("bool", "int", "float", "String", "Array", "Dictionary", "Color", "Vector", "expression")


class Entry:
    """One constant: lines [first, end) of the file hold it; its value starts at `value_at` of its
    first line and ends at `value_end` (an index into its last line)."""

    def __init__(self, name, annotation, section, first, end, value_at, value_end, value, comment, doc):
        self.name, self.annotation, self.section = name, annotation, section
        self.first, self.end, self.value_at, self.value_end = first, end, value_at, value_end
        self.value, self.comment, self.doc = value, comment, doc
        self.family = family(value)

    def multiline(self):
        return self.end - self.first > 1


def family(value):
    """What kind of value a constant's text is (FAMILIES): from its literal, else "expression"."""
    text = value.strip()
    if text in ("true", "false"):
        return "bool"
    if re.fullmatch(r"-?\d+", text) or re.fullmatch(r"0x[0-9a-fA-F]+", text):
        return "int"
    if re.fullmatch(r"-?(\d+\.\d*|\.\d+|\d+(\.\d*)?[eE][-+]?\d+)", text):
        return "float"
    if re.fullmatch(r'"([^"\\]|\\.)*"', text):
        return "String"
    if text.startswith("Color"):
        return "Color"
    if text.startswith("Vector"):
        return "Vector"
    if text.startswith("[") and _closes_at_end(text):
        return "Array"
    if text.startswith("{") and _closes_at_end(text):
        return "Dictionary"
    return "expression"


def _closes_at_end(text):
    depth = 0
    for index, char in _code_chars(text):
        if char in OPENERS:
            depth += 1
        elif char in CLOSERS:
            depth -= 1
            if depth == 0:
                return text[index + 1:].strip() == "" or text[index + 1:].lstrip().startswith("#")
    return False


def _code_chars(text):
    """(index, char) of `text` outside strings and comments."""
    quote = None
    index = 0
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "#":
            while index < len(text) and text[index] != "\n":
                index += 1
            continue
        else:
            yield index, char
        index += 1


def _comment_at(line):
    """Where the comment of a line starts (outside strings), or -1."""
    quote = None
    index = 0
    while index < len(line):
        char = line[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "#":
            return index
        index += 1
    return -1


def parse(text):
    lines = text.split("\n")
    entries = []
    section = ""
    doc = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.startswith(HEADER_RULE) and index + 2 < len(lines) and lines[index + 2].startswith(HEADER_RULE):
            section = lines[index + 1].lstrip("#").strip()
            index += 3
            doc = []
            continue
        found = CONST.match(line)
        if not found:
            doc = doc + [line.lstrip("#").strip()] if line.startswith("#") else []
            index += 1
            continue
        value_at = found.end()
        depth, end = 0, index
        while True:
            body = lines[end] if end > index else line[value_at:]
            for _, char in _code_chars(body):
                if char in OPENERS:
                    depth += 1
                elif char in CLOSERS:
                    depth -= 1
            if depth <= 0 or end + 1 >= len(lines):
                break
            end += 1
        last = lines[end]
        start_in_last = value_at if end == index else 0
        comment_at = _comment_at(last[start_in_last:])
        value_end = len(last) if comment_at < 0 else start_in_last + comment_at
        while value_end > start_in_last and last[value_end - 1] == " ":
            value_end -= 1
        if end == index:
            value = line[value_at:value_end]
        else:
            value = "\n".join([line[value_at:]] + lines[index + 1:end] + [last[:value_end]])
        first_comment = _comment_at(line[value_at:])
        comment = line[value_at + first_comment:].lstrip("#").strip() if first_comment >= 0 else ""
        entries.append(Entry(found.group(1), found.group(2) or "", section or "(top)", index, end + 1,
                             value_at, value_end, value, comment, doc))
        doc = []
        index = end + 1
    return entries


def sections(entries):
    out = []
    for entry in entries:
        if entry.section not in out:
            out.append(entry.section)
    return out


def check_value(entry, new_value):
    """"" when `new_value` (text) can stand for `entry`'s value, else why not: it keeps its kind
    (a number stays a number, a list a list; an expression may become anything)."""
    text = new_value.strip()
    if text == "":
        return "No value"
    new = family(text)
    old = entry.family
    numbers = ("int", "float")
    if old == "expression" or new == old:
        return ""
    if old in numbers and new in numbers:
        if entry.annotation == "int" and new == "float":
            return "%s is declared int" % entry.name
        return ""
    if new == "expression":
        return ""  # Godot's parse check decides
    return "%s was %s, not %s" % (entry.name, old, new)


def set_value(text, entry, new_value):
    """`text` with `entry`'s value replaced by `new_value`; the comment after it, and every other
    byte of the file, as they were."""
    lines = text.split("\n")
    head = lines[entry.first][:entry.value_at]
    tail = lines[entry.end - 1][entry.value_end:]
    replacement = (head + new_value.strip("\n") + tail).split("\n")
    return "\n".join(lines[:entry.first] + replacement + lines[entry.end:])
