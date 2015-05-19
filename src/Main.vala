//
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Clutter;
using Meta;

namespace Gala.Plugins.AlternateAltTab
{
	public delegate void ObjectCallback (Object object);

	class Settings : Granite.Services.Settings
	{
		public bool all_workspaces { get; set; default = false; }
		public bool animate { get; set; default = true; }
		public bool always_on_primary_monitor { get; set; default = false; }
		public int icon_size { get; set; default = 128; }

		static Settings? instance = null;

		private Settings ()
		{
			base ("org.pantheon.desktop.gala.plugins.alternate-alt-tab");
		}

		public static Settings get_default ()
		{
			if (instance == null)
				instance = new Settings ();

			return instance;
		}
	}

	public class Main : Gala.Plugin
	{
		const int SPACING = 12;
		const int PADDING = 24;
		const int MIN_OFFSET = 64;
		const int INDICATOR_BORDER = 6;
		const double ANIMATE_SCALE = 0.8;

		public bool opened { get; private set; default = false; }

		Gala.WindowManager? wm = null;
		Gala.ModalProxy modal_proxy = null;
		Actor container;
		Actor wrapper;
		Actor indicator;

		int modifier_mask;

		WindowIcon? current = null;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;
			var settings = Settings.get_default ();

			KeyBinding.set_custom_handler ("switch-applications", handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-applications-backward", handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows", handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows-backward", handle_switch_windows);

			var layout = new FlowLayout (FlowOrientation.HORIZONTAL);
			layout.column_spacing = layout.row_spacing = SPACING;

			wrapper = new Actor ();
			wrapper.background_color = { 0, 0, 0, 100 };
			wrapper.reactive = true;
			wrapper.set_pivot_point (0.5f, 0.5f);
			wrapper.key_release_event.connect (key_relase_event);

			container = new Actor ();
			container.layout_manager = layout;
			container.margin_left = container.margin_top =
				container.margin_right = container.margin_bottom = PADDING;

			indicator = new Actor ();
			indicator.background_color = { 255, 255, 255, 150 };
			indicator.width = settings.icon_size + INDICATOR_BORDER * 2;
			indicator.height = settings.icon_size + INDICATOR_BORDER * 2;
			indicator.set_easing_duration (200);

			wrapper.add_child (indicator);
			wrapper.add_child (container);
		}

		public override void destroy ()
		{
			if (wm == null)
				return;
		}

		void handle_switch_windows (Display display, Screen screen, Window? window,
#if HAS_MUTTER314
			KeyEvent event, Meta.KeyBinding binding)
#else
			X.Event event, Meta.KeyBinding binding)
#endif
		{
			var settings = Settings.get_default ();
			var workspace = settings.all_workspaces ? null : screen.get_active_workspace ();

			// copied from gnome-shell, finds the primary modifier in the mask
			var mask = binding.get_mask ();
			if (mask == 0)
				modifier_mask = 0;
			else {
				modifier_mask = 1;
				while (mask > 1) {
					mask >>= 1;
					modifier_mask <<= 1;
				}
			}

			if (!opened) {
				collect_windows (display, workspace);
				open_switcher ();

				update_indicator_position (true);
			}

			var binding_name = binding.get_name ();
			var backward = binding_name.has_suffix ("-backward");

			// FIXME for unknown reasons, switch-applications-backward won't be emitted, so we
			//       test manually if shift is held down
			// FIXME2: If backward is already true switch-applications-backward was
			//         emitted therefore it must not be changed again
			backward = backward || binding_name == "switch-applications"
				&& (get_current_modifiers () & ModifierType.SHIFT_MASK) != 0;

			next_window (display, workspace, backward);
		}

		void collect_windows (Display display, Workspace? workspace)
		{
			var screen = wm.get_screen ();
			var settings = Settings.get_default ();

#if HAS_MUTTER314
			var windows = display.get_tab_list (TabList.NORMAL, workspace);
			var current_window = display.get_tab_current (TabList.NORMAL, workspace);
#else
			var windows = display.get_tab_list (TabList.NORMAL, screen, workspace);
			var current_window = display.get_tab_current (TabList.NORMAL, screen, workspace);
#endif

			container.width = -1;
			container.destroy_all_children ();
			foreach (var window in windows) {
				var icon = new WindowIcon (window, settings.icon_size);
				if (window == current_window)
					current = icon;

				container.add_child (icon);
			}
		}

		void open_switcher ()
		{
			if (container.get_n_children () == 0) {
				return;
			}

			if (opened)
				return;

			var screen = wm.get_screen ();
			var settings = Settings.get_default ();

			indicator.visible = false;

			if (settings.animate) {
				wrapper.opacity = 0;
				wrapper.set_scale (ANIMATE_SCALE, ANIMATE_SCALE);
			}

			var monitor = settings.always_on_primary_monitor ?
				screen.get_primary_monitor () : screen.get_current_monitor ();
			var geom = screen.get_monitor_geometry (monitor);

			float container_width;
			container.get_preferred_width (settings.icon_size + PADDING * 2, null, out container_width);
			if (container_width + MIN_OFFSET * 2 > geom.width)
				container.width = geom.width - MIN_OFFSET * 2;

			float nat_width, nat_height;
			container.get_preferred_size (null, null, out nat_width, out nat_height);
			wrapper.width = nat_width;
			wrapper.height = nat_height;

			wrapper.set_position (geom.x + (geom.width - wrapper.width) / 2,
			                      geom.y + (geom.height - wrapper.height) / 2);

			wm.ui_group.insert_child_above (wrapper, null);

			wrapper.save_easing_state ();
			wrapper.set_easing_duration (100);
			wrapper.set_scale (1, 1);
			wrapper.opacity = 255;
			wrapper.restore_easing_state ();

			modal_proxy = wm.push_modal ();
			modal_proxy.keybinding_filter = keybinding_filter;
			opened = true;

			wrapper.grab_key_focus ();

			// if we did not have the grab before the key was released, close immediately
			if ((get_current_modifiers () & modifier_mask) == 0)
				close_switcher (screen.get_display ().get_current_time ());
		}

		void close_switcher (uint32 time)
		{
			if (!opened)
				return;

			wm.pop_modal (modal_proxy);
			opened = false;

			ObjectCallback remove_actor = () => {
				wm.ui_group.remove_child (wrapper);
			};

			if (Settings.get_default ().animate) {
				wrapper.save_easing_state ();
				wrapper.set_easing_duration (100);
				wrapper.set_scale (ANIMATE_SCALE, ANIMATE_SCALE);
				wrapper.opacity = 0;

				var transition = wrapper.get_transition ("opacity");
				if (transition != null)
					transition.completed.connect (() => remove_actor (this));
				else
					remove_actor (this);

				wrapper.restore_easing_state ();
			} else {
				remove_actor (this);
			}

			if (current.window == null) {
				return;
			}

			var window = current.window;
			var workspace = window.get_workspace ();
			if (workspace != wm.get_screen ().get_active_workspace ())
				workspace.activate_with_focus (window, time);
			else
				window.activate (time);
		}

		void next_window (Display display, Workspace? workspace, bool backward)
		{
			Actor actor;
			if (!backward) {
				actor = current.get_next_sibling ();
				if (actor == null)
					actor = container.get_child_at_index (0);
			} else {
				actor = current.get_previous_sibling ();
				if (actor == null)
					actor = container.get_child_at_index (container.get_n_children () - 1);
			}

			current = (WindowIcon) actor;

			update_indicator_position ();
		}

		void update_indicator_position (bool initial = false)
		{
			// FIXME there are some troubles with layouting, in some cases we
			//       are here too early, in which case all the children are at
			//       (0|0), so we can easily check for that and come back later
			if (container.get_n_children () > 1
				&& container.get_child_at_index (1).allocation.x1 < 1) {

				Idle.add (() => {
					update_indicator_position (initial);
					return false;
				});
				return;
			}

			float x, y;
			current.allocation.get_origin (out x, out y);

			if (initial) {
				indicator.save_easing_state ();
				indicator.set_easing_duration (0);
				indicator.visible = true;
			}

			indicator.x = container.margin_left + x - INDICATOR_BORDER;
			indicator.y = container.margin_top + y - INDICATOR_BORDER;

			if (initial)
				indicator.restore_easing_state ();
		}

		bool key_relase_event (KeyEvent event)
		{
			if ((get_current_modifiers () & modifier_mask) == 0) {
				close_switcher (event.time);
				return true;
			}

			switch (event.keyval) {
				case Key.Escape:
					close_switcher (event.time);
					return true;
			}

			return false;
		}

		Gdk.ModifierType get_current_modifiers ()
		{
			Gdk.ModifierType modifiers;
			double[] axes = {};
			Gdk.Display.get_default ().get_device_manager ().get_client_pointer ()
				.get_state (Gdk.get_default_root_window (), axes, out modifiers);

			return modifiers;
		}

		bool keybinding_filter (KeyBinding binding)
		{
			// don't block any keybinding for the time being
			// return true for any keybinding that should be handled here.
			return false;
		}
	}
}

public Gala.PluginInfo register_plugin ()
{
	return Gala.PluginInfo () {
		name = "Alternate Alt Tab",
		author = "Gala Developers",
		plugin_type = typeof (Gala.Plugins.AlternateAltTab.Main),
		provides = Gala.PluginFunction.WINDOW_SWITCHER,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}

