using Gtk;
using Gst;

public class VideoPlayer : Window {
	private Element playbin;
	private Gtk.Button play_button;
	private Gtk.Scale slider;
	private bool playing = false;
	private uint tid;
	private Gtk.Box vbox;
	private const SeekFlags SEEK_FLAGS=(SeekFlags.FLUSH|SeekFlags.ACCURATE|SeekFlags.KEY_UNIT);
	private Gst.ClockTime duration;

	public VideoPlayer() {
		Widget video_area;
		string playbinx;

		duration =  (int64)0x7ffffffffffffff;
        set_icon_name("mwp_icon");

		if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
			playbinx = "playbin";
		}
		playbin = ElementFactory.make (playbinx, playbinx);
		var gtksink = ElementFactory.make ("gtksink", "sink");
		gtksink.get ("widget", out video_area);
		playbin["video-sink"] = gtksink;

		vbox = new Box (Gtk.Orientation.VERTICAL, 0);
		vbox.pack_start (video_area);

		play_button = new Button.from_icon_name ("gtk-media-play", Gtk.IconSize.BUTTON);
		play_button.clicked.connect (on_play);
		set_size_request(480, 400);
		add (vbox);
		var bus = playbin.get_bus ();
		bus.add_watch(Priority.DEFAULT, bus_callback);

		var header_bar = new Gtk.HeaderBar ();
		header_bar.decoration_layout = "icon,menu:minimize,maximize,close";
		header_bar.set_title ("Video Replay");
		header_bar.show_close_button = true;
		var vb = new Gtk.VolumeButton();
		double vol;
		playbin.get("volume", out vol);
		vb.value = vol;
		vb.value_changed.connect((v) => {
				playbin.set("volume", v);
			});

		header_bar.pack_end (vb);
		header_bar.pack_start (play_button);

		header_bar.has_subtitle = false;
		type_hint = Gdk.WindowTypeHint.NORMAL;
		set_titlebar (header_bar);
			destroy.connect (() => {
					if (tid > 0)
						Source.remove(tid);
					playbin.set_state (Gst.State.NULL);
				});
		}


	private void add_slider() {
		slider = new Scale.with_range(Orientation.HORIZONTAL, 0, 1, 1);
		slider.set_draw_value(false);
		slider.change_value.connect((st, d) => {
				int64 pos = (int64)(1e9*d);
				playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, pos);
				return true;
			});

		var hbox = new Box (Gtk.Orientation.HORIZONTAL, 0);
		  var rewind = new Button.from_icon_name ("gtk-media-previous", Gtk.IconSize.BUTTON);
		  rewind.clicked.connect(() => {
				  Gst.State st;
				  playbin.get_state (out st, null, CLOCK_TIME_NONE);
				  playbin.set_state (Gst.State.PAUSED);
				  playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, (int64)0);
				  playbin.set_state (st);
			  });
		  var forward = new Button.from_icon_name ("gtk-media-next", Gtk.IconSize.BUTTON);
		  forward.clicked.connect(() => {
				  playbin.set_state (Gst.State.PAUSED);
				  playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, (int64)duration);

			  });
		  hbox.pack_start (rewind, false, false, 0);
		  hbox.pack_start (slider, true, true);
		  hbox.pack_start (forward, false, false, 0);
		  vbox.pack_start(hbox, false);
	}

	public void set_slider_max(Gst.ClockTime max) {
		if (max > 0) {
			duration = max;
			double rt =  max / 1e9;
			add_slider();
			slider.set_range(0.0, rt);
		}
	}

	public void set_slider_value(double value) {
		if (slider != null)
			slider.set_value(value);
	}

	public void start_at(int64 tstart = 0) {
		if(tstart < 0) {
			int msec = (int)(-1*(tstart / 1000000));
			Timeout.add(msec, () => {
					on_play();
					return Source.REMOVE;
				});
		} else {
			on_play();
			if (tstart > 0) {
				playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, tstart);
			}
		}
	}

	public void add_stream(string fn, bool force=true) {
		bool start = false;
		if (force || !fn.has_prefix("file://")) {
			start = true;
		}
		playbin["uri"] = fn;
		if (start) {
			on_play();
		} else {
			playbin.set_state (Gst.State.PAUSED);
		}
		tid = Timeout.add(50, () => {
				Gst.Format fmt = Gst.Format.TIME;
				int64 current = -1;
				if (playbin.query_position (fmt, out current)) {
					double rt = current/1e9;
					set_slider_value(rt);
				}
				return true;
			});
	}

	private bool bus_callback (Gst.Bus bus, Gst.Message message) {
		switch (message.type) {
		case Gst.MessageType.ERROR:
			GLib.Error err;
			string debug;
			message.parse_error (out err, out debug);
			MWPLog.message("Video error: %s\n", err.message);
			destroy();
			break;
		case Gst.MessageType.EOS:
			playing = false;
			playbin.set_state (Gst.State.READY);
			break;
		case Gst.MessageType.STATE_CHANGED:
			Gst.State oldstate;
			Gst.State newstate;
			Gst.State pending;
			message.parse_state_changed (out oldstate, out newstate, out pending);
/**
			if(newstate == Gst.State.PLAYING && !playing) {
				var img = new Gtk.Image.from_icon_name("gtk-media-pause", Gtk.IconSize.BUTTON);
					play_button.set_image(img);
					playing = true;
			}
			if (newstate == Gst.State.PAUSED && playing) {
				var img = new Gtk.Image.from_icon_name("gtk-media-play", Gtk.IconSize.BUTTON);
				play_button.set_image(img);
				playing = false;
				}
**/
			if(newstate == Gst.State.PLAYING) {
				var img = new Gtk.Image.from_icon_name("gtk-media-pause", Gtk.IconSize.BUTTON);
					play_button.set_image(img);
					playing = true;
			} else {
				var img = new Gtk.Image.from_icon_name("gtk-media-play", Gtk.IconSize.BUTTON);
				play_button.set_image(img);
				playing = false;
			}
			break;
		default:
			break;
		}
		return true;
	}

	void on_play() {
		if (playing ==  false)  {
			playbin.set_state (Gst.State.PLAYING);
		} else {
			playbin.set_state (Gst.State.PAUSED);
		}
	}
	public static Gst.ClockTime discover(string fn) {
		Gst.ClockTime id = 0;
		try {
			var d = new Gst.PbUtils.Discoverer((Gst.ClockTime) (Gst.SECOND * 5));
			var di = d.discover_uri(fn);
			id = di.get_duration ();
		} catch {}
		return id;
	}
}

public class V4L2_dialog : Dialog {

	private Gtk.Entry e;
	private Gtk.RadioButton rb0;
	private Gtk.RadioButton rb1;

	public V4L2_dialog(Gtk.ComboBoxText viddev_c) {
		this.title = "Select Video Source";
		this.border_width = 5;
		rb0  = new Gtk.RadioButton.with_label_from_widget (null, "Webcams");
		rb1 = new Gtk.RadioButton.with_label_from_widget (rb0, "URI");
		e = new Gtk.Entry();
		e.placeholder_text = "http://daria.co.uk/stream.mp4";
		e.input_purpose = Gtk.InputPurpose.URL;
		var content = get_content_area () as Box;
		var grid = new Gtk.Grid();
		grid.attach(rb0, 0, 0);
		grid.attach(viddev_c, 1, 0);
		grid.attach(rb1, 0, 1);
		grid.attach(e, 1, 1);
		content.pack_start (grid, false, true, 2);
		add_button ("Close", 1001);
		add_button ("OK", 1000);
		set_modal(true);
	}

	public int runner(out string uri) {
		uri = null;
		int res = -1;
		show_all();
		var id = run();
		switch (id) {
		case 1000:
				if (rb0.active) {
					res = 0;
				} else {
					res = 1;
					uri = e.text;
				}
				break;
				case 1001:
					break;
				}
		hide();
		return res;
	}
}
