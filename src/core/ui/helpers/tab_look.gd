# TabLook: how every window marks its open tab: the title in brackets and the open look, the tab's
# own look with "Open" after it (main_theme's TabButtonOpen, LargeTabButtonOpen: amber words). The
# colour is the theme's, so it is changed there, not here.

extends Reference

const OPEN_SUFFIX = "Open"


# `button` (a TabButton or LargeTabButton) showing `title`, open or not.
static func show(button: Button, title: String, open: bool) -> void:
	var look: String = button.theme_type_variation
	if look.ends_with(OPEN_SUFFIX):
		look = look.substr(0, look.length() - OPEN_SUFFIX.length())
	button.theme_type_variation = look + OPEN_SUFFIX if open else look
	button.text = ("[%s]" if open else "%s") % title
