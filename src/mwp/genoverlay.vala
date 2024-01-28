using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public class OverlayItem : Object {
    public struct StyleItem {
        bool styled;
		bool line_dotted;
        string line_colour;
        string fill_colour;
        string point_colour;
		int line_width;
    }

    public struct Point {
        double latitude;
        double longitude;
		int altitude;
    }

	public enum OLType {
		UNKNOWN=0,
		POINT=1,
		LINESTRING=2,
		POLYGON=3,
	}

	public struct CircData {
		double lat;
		double lon;
		double radius_nm;
	}

	public uint8 idx;
	public OLType type;
    public string? name;
	public string? desc;
	public StyleItem? styleinfo;
	public Point[] pts;
	public CircData circ;
	public Champlain.PathLayer? pl;
	public Champlain.Label? mk;


	public OverlayItem() {
		pl = new Champlain.PathLayer();
		pts = {};
	}

	public void remove_path() {
		pl.remove_all();
	}

	public void show_point() {
		Clutter.Color black = { 0,0,0, 0xff };
		if(mk == null) {
			mk = new Champlain.Label(); //.with_text (o.name,"Sans 10",null,null);
		}
		mk.set_text(name);
		mk.set_font_name("Sans 10");
		mk.set_alignment (Pango.Alignment.RIGHT);
		mk.set_color(Clutter.Color.from_string(styleinfo.point_colour));
		mk.set_text_color(black);
		mk.set_location (pts[0].latitude, pts[0].longitude);
		mk.set_draggable(false);
		mk.set_selectable(false);
	}

	public void show_linestring() {
		pl.closed=false;
		pl.set_stroke_color(Clutter.Color.from_string(styleinfo.line_colour));
		pl.set_stroke_width (styleinfo.line_width);
		foreach (var p in pts) {
			var l =  new  Champlain.Point();
			l.set_location(p.latitude, p.longitude);
			pl.add_node(l);
		}
	}

	public void show_polygon() {
			pl.closed=true;
			pl.set_stroke_color(Clutter.Color.from_string(styleinfo.line_colour));
			pl.set_stroke_width (styleinfo.line_width);
			pl.fill = (styleinfo.fill_colour != null);
			if (pl.fill)
				pl.set_fill_color(Clutter.Color.from_string(styleinfo.fill_colour));
			if (styleinfo.line_dotted) {
				var llist = new List<uint>();
				llist.append(5);
				llist.append(5);
				pl.set_dash(llist);
			}
			foreach (var p in pts) {
				var l =  new  Champlain.Point();
				l.set_location(p.latitude, p.longitude);
				pl.add_node(l);
			}
	}

	public void display() {
		switch(this.type) {
		case OLType.POINT:
			show_point();
			break;
		case OLType.LINESTRING:
			show_linestring();
			break;
		case OLType.POLYGON:
			show_polygon();
			break;
		case OLType.UNKNOWN:
			break;
		}
	}
}


public class Overlay : Object {
    private Champlain.View view;
    private Champlain.MarkerLayer mlayer;
	private List<OverlayItem?> elements;

	public unowned List<OverlayItem?> get_elements() {
		return elements;
	}

    private void at_bottom(Champlain.Layer layer) {
        var pp = layer.get_parent();
        pp.set_child_at_index(layer,0);
    }

	public Overlay(Champlain.View _view, bool _edit = false) {
        view = _view;
		editable = _edit;
		elements= new List<OverlayItem?>();
        mlayer = new Champlain.MarkerLayer();
        view.add_layer (mlayer);
        at_bottom(mlayer);
	}

	public void remove() {
		mlayer.remove_all();
		elements.foreach((el) => {
				el.remove_path();
				view.remove_layer(el.pl);
			});
    }

	/*
	public void remove() {
		mlayer.remove_all();
		while(!players.is_empty()) {
			var p = players.data;
			p.remove_all();
			view.remove_layer(p);
			players.remove_link(players);
		}
    }
	*/

	public void add_element(OverlayItem o) {
		elements.append(o);
	}

	public void display() {
		elements.foreach((o) => {
				stderr.printf("DBG: Add element %s\n", o.name);
				o.display();
				switch(o.type) {
				case OverlayItem.OLType.POINT:
					mlayer.add_marker (o.mk);
					break;
				case OverlayItem.OLType.LINESTRING:
				case OverlayItem.OLType.POLYGON:
					view.add_layer (o.pl);
					at_bottom(o.pl);
					break;
				case OverlayItem.OLType.UNKNOWN:
					break;
				}
			});
	}
}
