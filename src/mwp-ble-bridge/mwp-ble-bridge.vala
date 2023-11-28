extern unowned string ptsname(int fd);

namespace DevManager {
  public static BluetoothMgr btmgr;
}

namespace MWPLog {
	public void  message(string format, ...) {
		var args = va_list();
		stdout.vprintf(format, args);
	}
}

public class GattTest : Application {
	private string? addr;
	private BleSerial gs;
	private int rdfd;
	private int wrfd;
	private int pfd;
	private string dpath;
	private int mtu;
	private int delay;
	private bool verbose;

	public GattTest () {
        Object (application_id: "org.mwptools.mwp-ble-bridge",
				flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        Unix.signal_add (
            Posix.Signal.INT,
            on_sigint,
            Priority.DEFAULT
        );
		startup.connect (on_startup);
        shutdown.connect (on_shutdown);
		delay = 500;
		var options = new OptionEntry[] {
			{ "address", 'a', 0, OptionArg.STRING, addr, "BT address", null},
			{ "settle", 's', 0, OptionArg.INT, ref delay, "BT settle time (ms)", null},
			{ "verrbose", 's', 0, OptionArg.NONE, null, "BT settle time (ms)", null},
            { "version", 'v', 0, OptionArg.NONE, null, "show version", null},
			{null}
		};
		set_option_context_parameter_string(" - BLE serial bridge");
		set_option_context_description(" requires a BT address or $MWP_BLE to be set");
		add_main_option_entries(options);
		handle_local_options.connect(do_handle_local_options);
	}

	public override int command_line (ApplicationCommandLine command_line) {
		string[] args = command_line.get_arguments ();
		var o = command_line.get_options_dict();
		o.lookup("address", "s", ref addr);
		o.lookup("settle", "i", ref delay);
		o.lookup("verbose", "b", ref verbose);

		if (addr == null) {
			if (args.length > 1) {
				addr = args[1];
			} else {
				addr =  Environment.get_variable("MWP_BLE");
			}
		}
		if(addr == null) {
			stderr.printf("usage: mwp-ble-bridge --address ADDR (or set $MWP_BLE)\n");
			return 127;
		} else {
			activate();
			return 0;
		}
	}

	private int do_handle_local_options(VariantDict o) {
        if (o.contains("version")) {
            stdout.printf("0.0.1\n");
            return 0;
        }
		return -1;
    }

	private void init () {
		DevManager.btmgr = new BluetoothMgr();
		DevManager.btmgr.init();
		//		message("delay %d", delay);
		Timeout.add(delay, () => {
				gs = new BleSerial();
				gs.bdev = DevManager.btmgr.get_device(addr, out dpath);
				MWPLog.message("Open BLE device %s\n", addr);
				gs.bdev.connected_changed.connect((v) => {
						if(v) {
							MWPLog.message("Connected\n");
						} else {
							MWPLog.message("BLE Disconnected\n");
						}
					});
				if (gs.bdev.connect()) {
					int gid = gs.find_service(dpath);
					if (gid != -1) {
						mtu = gs.get_bridge_fds(gid, out rdfd, out wrfd);
						MWPLog.message("BLE chipset %s, mtu %d\n", gs.get_chipset(gid), mtu);
					} else {
						MWPLog.message("Failed to find service\n");
						close_session();
					}
					start_session();
				} else {
					this.quit();
				}
				return false;
			});
	}

	public override void activate () {
		hold ();
		Idle.add(() => {
				init();
				return false;
			});
		return;
	}

	private void close_session () {
		if(rdfd != -1)
			Posix.close(rdfd);
		if(wrfd != -1)
			Posix.close(wrfd);
		if(pfd != -1)
			Posix.close(pfd);
		pfd = rdfd = wrfd = -1;
		if (gs != null) {
			MWPLog.message("Disconnect\n");
			gs.bdev.disconnect();
		}
		this.quit();
	}

	private void start_session () {
		if (rdfd != -1 && wrfd != -1) {
			pfd = Posix.posix_openpt(Posix.O_RDWR|Posix.O_NONBLOCK);
			if (pfd != -1) {
				Posix.grantpt(pfd);
				Posix.unlockpt(pfd);
				unowned string s = ptsname(pfd);
				print("%s <=> %s\n",addr, s);
				ioreader();
			} else {
				close_session();
			}
		}
	}

	private void ioreader() {
		ioreader_async.begin((obj,res) => {
				int bres = ioreader_async.end(res);
				if(verbose) {
					MWPLog.message("End of reader (%d)", bres);
				}
				close_session();
			});
	}

	private async int ioreader_async () {
		var thr = new Thread<int> ("mwp-ble", () => {
				uint8 buf[512];
				int done = 0;
				while (done == 0) {
					var nw = Posix.read(pfd, buf, 20);
					if (nw > 0) {
						Posix.write(wrfd, buf, nw);
					} else if (nw < 0) {
						if(Posix.errno == Posix.EAGAIN) {
							Thread.usleep(1000);
						} else {
							done = Posix.errno;
						}
					} else {
						done =  -3;
					}
					var nr = Posix.read(rdfd, buf, 512);
					if (nr > 0) {
						Posix.write(pfd, buf, nr);
					} else if (nr < 0) {
						if(Posix.errno == Posix.EAGAIN) {
							Thread.usleep(1000);
						} else {
							done = Posix.errno;
						}
					} else {
						done =  -3;
					}
				}
				Idle.add (ioreader_async.callback);
				return done;
			});
		yield;
		return thr.join();
	}

	private bool on_sigint () {
		close_session();
		return Source.REMOVE;
    }

	private void on_startup() {	}

	private void on_shutdown() {
	}
}

public static int main (string[] args) {
	var ga = new GattTest();
	ga.run(args);
	return 0;
}
