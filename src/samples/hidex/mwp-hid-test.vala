using SDL;

int main(string?[]args) {
	bool []gcs = new bool[16];

	int njoy = SDL.init (SDL.InitFlag.JOYSTICK);
	if (njoy < 0) {
		print("Unable to initialize the joystick subsystem.\n");
        return 127;
    }
	njoy = SDL.Input.Joystick.count();
	print("There are %d joysticks connected.\n", njoy);

	for(int i=0; i < njoy; i++) {
		var guid = SDL.Input.Joystick.get_guid_from_device(i);
		var gstr = SDL.Input.Joystick.get_guid_string(guid);
		gcs[i] = SDL.Input.GameController.is_game_controller(i);
		print("Entry %d, %s guid=%s game controller=%s\n", i, SDL.Input.Joystick.get_name_for_index(i),gstr,  gcs[i].to_string());
	}

	SDL.Input.Joystick js;
	int jid = 0;
	if (njoy > 0) {
		if(njoy > 1) {
			print("Enter controller ID: ");
			string? jstr = stdin.read_line ();
			if(jstr == null) {
				return 1;
			}
			var id = int.parse(jstr);
			if (id < 0 || id >= njoy) {
				return 2;
			}
			jid = id;
		}

		js = new SDL.Input.Joystick(jid);
		if(gcs[jid] && args.length > 1) {
			SDL.Input.GameController.load_mapping_file(args[1]);
		}
		if (js == null) {
            print("There was an error opening joystick 0.\n");
            return 127;
        } else {
			print("Name: %s\n", js.get_name());
			print("No. axes %d\n", js.num_axes());
			print("No. balls %d\n", js.num_balls());
			print("No. buttons %d\n", js.num_buttons());
			print("No. hats %d\n", js.num_hats());
		}
    } else {
        print("There are no joysticks connected. Exiting...\n");
        return 127;
    }

    SDL.Event event;

	while (SDL.Event.wait (out event) == 1) {
		if (event.type == SDL.EventType.QUIT)
			break;
		switch(event.type) {
		case SDL.EventType.JOYAXISMOTION:
			print("Joy Axis %d value %d.\n", event.jaxis.axis, event.jaxis.value);
			break;
		case SDL.EventType.JOYHATMOTION:
			print("Joy Hat %d value %d.\n", event.jhat.hat, event.jhat.value);
			break;
		case SDL.EventType.JOYBUTTONDOWN:
			print("Joy Button %d pressed.\n", event.jbutton.button);
			break;
		case SDL.EventType.JOYBUTTONUP:
			print("Joy Button %d released.\n", event.jbutton.button);
			break;
		case SDL.EventType.JOYDEVICEADDED:
			print("Joystick %d connected\n", event.jdevice.which);
			break;
		case SDL.EventType.JOYDEVICEREMOVED:
			print("Joystick %d removed.\n", event.jdevice.which);
			break;
		case SDL.EventType.CONTROLLERAXISMOTION:
			print("Controller Axis %d value %d.\n", event.caxis.axis, event.caxis.value);
			break;
		case SDL.EventType.CONTROLLERBUTTONDOWN:
			print("Controller Button %d pressed.\n", event.cbutton.button);
			break;
		case SDL.EventType.CONTROLLERBUTTONUP:
			print("Controller Button %d released.\n", event.cbutton.button);
			break;
		case SDL.EventType.CONTROLLERDEVICEADDED:
			print("Controller %d connected\n", event.cdevice.which);
			break;
		case SDL.EventType.CONTROLLERDEVICEREMOVED:
			print("Controller %d removed.\n", event.cdevice.which);
			break;
		case SDL.EventType.CONTROLLERDEVICEREMAPPED:
			print("Controller %d remapped.\n", event.cdevice.which);
			break;
		case 607:
			//	print("Joystick %d battery update\n", event.jdevice.which);
			break;
		case 608:
			//print("Joystick %d update complete\n", event.jdevice.which);
			break;
		default:
			print("Unhandled %d %x\n", event.type, event.type);
			break;
		}
	}
    SDL.quit ();
	return 0;
}