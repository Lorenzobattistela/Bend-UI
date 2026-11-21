# Laws of the components in Bend (UI.bend) and of the comparison of two views (PATCH.bend).
# Each component law says: this call is exactly this tree, the markup README.md gives for it.
# Change a class name, a tag or an attribute in UI.bend and the proof fails.
import Base
import ./Web.bend as Web
import ./UI.bend as Ui
import ./PATCH.bend as P

# A page's messages, for the laws.
type Ev is Data:
  go{}
  typing{value: String}
  set{value: String}

# ---------- Components ----------

# LAW: a button is <button class="btn btn--filled">Save</button>, and a click sends its message.
law button_is_its_markup:
  {Ui.button(Ev, [Ui.btn_filled{}], "Save", go{}) == Web.node{"button", [Web.attr{"class", "btn btn--filled"}, Web.on{Web.click{go{}}}], [Web.text{"Save"}]} : Web.HTML<Ev>}

# LAW: modifiers are written in the order given: class="btn btn--bordered btn--neutral".
law button_modifiers_keep_their_order:
  {Ui.button(Ev, [Ui.btn_bordered{}, Ui.btn_neutral{}], "Cancel", go{}) == Web.node{"button", [Web.attr{"class", "btn btn--bordered btn--neutral"}, Web.on{Web.click{go{}}}], [Web.text{"Cancel"}]} : Web.HTML<Ev>}

# LAW: the page's own classes come after the component's.
law own_classes_come_last:
  {Ui.button_with(Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "mine", [], []) == Web.node{"button", [Web.attr{"class", "btn btn--ghost btn--toggle mine"}], []} : Web.HTML<Ev>}

# LAW: an icon is <svg class="icon"><use href="#i-plus"/></svg>.
law icon_is_its_markup:
  {Ui.icon(Ev, "plus") == Web.node{"svg", [Web.attr{"class", "icon"}], [Web.node{"use", [Web.attr{"href", "#i-plus"}], []}]} : Web.HTML<Ev>}

# LAW: an icon button has a name: <button class="btn btn--plain btn--neutral btn--sm btn--icon" aria-label="Add"><svg class="icon"><use href="#i-plus"/></svg></button>.
law icon_button_has_a_name:
  {Ui.icon_button(Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}], "Add", "plus", go{}) == Web.node{"button", [Web.attr{"class", "btn btn--plain btn--neutral btn--sm btn--icon"}, Web.attr{"aria-label", "Add"}, Web.on{Web.click{go{}}}], [Web.node{"svg", [Web.attr{"class", "icon"}], [Web.node{"use", [Web.attr{"href", "#i-plus"}], []}]}]} : Web.HTML<Ev>}

# LAW: a segmented is <div class="segmented"> with one <button aria-pressed> per choice, and Bend holds the choice (data-manual).
law segmented_is_its_markup:
  {Ui.segmented_with(Ev, [], "", [], [Ui.choice(Ev, "One", True{}, go{}), Ui.choice(Ev, "Two", False{}, go{})]) == Web.node{"div", [Web.attr{"class", "segmented"}, Web.attr{"data-manual", ""}], [Web.node{"button", [Web.attr{"aria-pressed", "true"}, Web.on{Web.click{go{}}}], [Web.text{"One"}]}, Web.node{"button", [Web.attr{"aria-pressed", "false"}, Web.on{Web.click{go{}}}], [Web.text{"Two"}]}]} : Web.HTML<Ev>}

# LAW: a named group says so: class="segmented segmented--slide" role="group" aria-label="Range".
law segmented_group_is_named:
  {Ui.segmented(Ev, [Ui.seg_slide{}], "Range", []) == Web.node{"div", [Web.attr{"class", "segmented segmented--slide"}, Web.attr{"data-manual", ""}, Web.attr{"role", "group"}, Web.attr{"aria-label", "Range"}], []} : Web.HTML<Ev>}

# LAW: a menu starts closed: <div class="menu" role="menu" hidden>.
law menu_starts_closed:
  {Ui.menu(Ev, [], []) == Web.node{"div", [Web.attr{"class", "menu"}, Web.attr{"role", "menu"}, Web.attr{"hidden", ""}], []} : Web.HTML<Ev>}

# LAW: the button that opens a menu says it has one and that it is closed.
law trigger_says_it_has_a_menu:
  {Ui.trigger_with(Ev, [Ui.btn_ghost{}], "", [], []) == Web.node{"button", [Web.attr{"class", "btn btn--ghost"}, Web.attr{"aria-haspopup", "menu"}, Web.attr{"aria-expanded", "false"}], []} : Web.HTML<Ev>}

# LAW: a dropdown is the button and then the menu, inside <div class="dropdown">.
law dropdown_is_button_then_menu:
  {Ui.dropdown(Ev, Web.text{"a"}, Web.text{"b"}) == Web.node{"div", [Web.attr{"class", "dropdown"}], [Web.text{"a"}, Web.text{"b"}]} : Web.HTML<Ev>}

# LAW: a menu item is <button class="menu__item" role="menuitem"> with a small icon and its text.
law menu_item_is_its_markup:
  {Ui.menu_item(Ev, "plus", "Add node below", go{}) == Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"role", "menuitem"}, Web.on{Web.click{go{}}}], [Web.node{"svg", [Web.attr{"class", "icon icon--sm"}], [Web.node{"use", [Web.attr{"href", "#i-plus"}], []}]}, Web.node{"span", [], [Web.text{"Add node below"}]}]} : Web.HTML<Ev>}

# LAW: one of a set says whether it is checked and carries its check.
law menu_radio_is_its_markup:
  {Ui.menu_radio(Ev, "heading-1", "Title", False{}, go{}) == Web.node{"button", [Web.attr{"class", "menu__item"}, Web.attr{"role", "menuitemradio"}, Web.attr{"aria-checked", "false"}, Web.on{Web.click{go{}}}], [Web.node{"svg", [Web.attr{"class", "icon"}], [Web.node{"use", [Web.attr{"href", "#i-heading-1"}], []}]}, Web.node{"span", [], [Web.text{"Title"}]}, Web.node{"svg", [Web.attr{"class", "icon icon--sm menu__check"}], [Web.node{"use", [Web.attr{"href", "#i-check"}], []}]}]} : Web.HTML<Ev>}

# LAW: a separator is <hr class="separator">.
law separator_is_its_markup:
  {Ui.separator(Ev) == Web.node{"hr", [Web.attr{"class", "separator"}], []} : Web.HTML<Ev>}

# LAW: a field ties its label to its control: <label class="field" for="name"><span class="field__label">Name</span>…</label>.
law field_ties_label_to_control:
  {Ui.field(Ev, "name", "Name", Ui.input_with(Ev, [], "", [Web.attr{"id", "name"}])) == Web.node{"label", [Web.attr{"class", "field"}, Web.attr{"for", "name"}], [Web.node{"span", [Web.attr{"class", "field__label"}], [Web.text{"Name"}]}, Web.node{"input", [Web.attr{"class", "input"}, Web.attr{"id", "name"}], []}]} : Web.HTML<Ev>}

# LAW: a number field says each keystroke and the commit, and shows the text Bend gives it.
law number_input_listens:
  {Ui.number_input(Ev, [Ui.input_sm{}], "x", "1.00", "0.1", typing{""}, set{""}) == Web.node{"input", [Web.attr{"class", "input input--sm"}, Web.attr{"id", "x"}, Web.attr{"type", "number"}, Web.attr{"step", "0.1"}, Web.attr{"value", "1.00"}, Web.on{Web.input{typing{""}}}, Web.on{Web.change{set{""}}}], []} : Web.HTML<Ev>}

# LAW: a panel is <div class="panel"><div class="panel__header">…</div><div class="panel__body">…</div></div>.
law panel_is_its_markup:
  {Ui.panel(Ev, [Web.text{"Header"}], [Web.text{"Body"}]) == Web.node{"div", [Web.attr{"class", "panel"}], [Web.node{"div", [Web.attr{"class", "panel__header"}], [Web.text{"Header"}]}, Web.node{"div", [Web.attr{"class", "panel__body"}], [Web.text{"Body"}]}]} : Web.HTML<Ev>}

# LAW: a disclosure is the browser's <details>, its summary starting with the chevron.
law disclosure_is_its_markup:
  {Ui.disclosure(Ev, "Laws", []) == Web.node{"details", [Web.attr{"class", "disclosure"}], [Web.node{"summary", [], [Web.node{"svg", [Web.attr{"class", "icon icon--sm disclosure__chevron"}], [Web.node{"use", [Web.attr{"href", "#i-chevron-down"}], []}]}, Web.node{"span", [Web.attr{"class", "disclosure__title"}], [Web.text{"Laws"}]}]}]} : Web.HTML<Ev>}

# LAW: a dot is <span class="dot dot--success"></span>.
law dot_is_its_markup:
  {Ui.dot(Ev, [Ui.dot_success{}]) == Web.node{"span", [Web.attr{"class", "dot dot--success"}], []} : Web.HTML<Ev>}

# ---------- The comparison of two views ----------

# LAW: the same text needs nothing done.
law same_text_is_kept:
  {P.diff(Ev, Web.text{"a"}, Web.text{"a"}) == [P.keep{}] : List<&2, P.Patch<Ev>>}

# LAW: another text is written in place: the node stays.
law other_text_is_rewritten:
  {P.diff(Ev, Web.text{"a"}, Web.text{"b"}) == [P.retext{"b"}] : List<&2, P.Patch<Ev>>}

# LAW: another tag makes the node again.
law other_tag_is_made_again:
  {P.diff(Ev, Web.node{"a", [], []}, Web.node{"b", [], []}) == [P.swap{Web.node{"b", [], []}}] : List<&2, P.Patch<Ev>>}

# LAW: an attribute that holds the same text is not touched.
law same_attribute_is_left_alone:
  {P.diff(Ev, Web.node{"a", [Web.attr{"class", "x"}], []}, Web.node{"a", [Web.attr{"class", "x"}], []}) == [P.edit{[], [], [], 0n, []}] : List<&2, P.Patch<Ev>>}

# LAW: an attribute that holds another text is set, and nothing is taken off.
law changed_attribute_is_set:
  {P.diff(Ev, Web.node{"a", [Web.attr{"class", "x"}], []}, Web.node{"a", [Web.attr{"class", "y"}], []}) == [P.edit{[], [Web.attr{"class", "y"}], [], 0n, []}] : List<&2, P.Patch<Ev>>}

# LAW: an attribute that went away is taken off.
law gone_attribute_is_taken_off:
  {P.diff(Ev, Web.node{"a", [Web.attr{"hidden", ""}], []}, Web.node{"a", [], []}) == [P.edit{[Web.attr{"hidden", ""}], [], [], 0n, []}] : List<&2, P.Patch<Ev>>}

# LAW: a child past the end of the last view is added, and the ones before it are patched in place.
law new_child_is_added_at_the_end:
  {P.diff(Ev, Web.node{"a", [], [Web.text{"1"}]}, Web.node{"a", [], [Web.text{"1"}, Web.text{"2"}]}) == [P.edit{[], [], [P.keep{}], 0n, [Web.text{"2"}]}] : List<&2, P.Patch<Ev>>}

# LAW: children past the end of the next view are cut from the end.
law gone_children_are_cut_from_the_end:
  {P.diff(Ev, Web.node{"a", [], [Web.text{"1"}, Web.text{"2"}, Web.text{"3"}]}, Web.node{"a", [], [Web.text{"1"}]}) == [P.edit{[], [], [P.keep{}], 2n, []}] : List<&2, P.Patch<Ev>>}

# LAW: an event is always set again (a message is never compared), and a clock of the same interval is not taken off.
law event_is_set_again:
  {P.diff(Ev, Web.node{"a", [Web.on{Web.click{go{}}}, Web.every_ms{1000, go{}}], []}, Web.node{"a", [Web.on{Web.click{go{}}}, Web.every_ms{1000, go{}}], []}) == [P.edit{[], [Web.on{Web.click{go{}}}, Web.every_ms{1000, go{}}], [], 0n, []}] : List<&2, P.Patch<Ev>>}
