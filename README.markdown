# A Dark Menu Bar for OS/X

This is a little app that turns your menu bar black.  It is derived from
an application called Nocturne, by Blacktree, except that this version
is focused primarily on the menu bar and not on the overall screen
tinting that was present in Nocturne.

It also has improved behavior in the presence of Lion full-screen
applications.

## How it works

An overlay window is created that sits in front of the menu bar and
applies a filters to change the menubar color.

By default it uses a hue filter to change the color, but there is a
hidden preference that can be used to change this to a saturation filter
in case you don't like how the colors are manipulated by the hue filter.

In Mac OS X 10.9 Mavericks, Apple took out the private API for filter windows,
but a workaround has been made. For computers running Mavericks, the
application takes a screenshot of your menubar many times every second
and uses the information from that to overlay an inverted menubar window.

## Preferences

There is no preference GUI (pull requests to add this are welcome!) but
you can set the following preferences via the command line:

### Enable/Disable Menu Bar Item

By default, MenuBarFilter provides a menu item that allows you to quit
it.  You can turn this off by running the following command and then
restarting MenuBarFilter:

```shell
defaults write org.wezfurlong.MenuBarFilter enableMenu NO
```

### Enable/Disable Hue Filter

By default, MenuBarFilter uses a Hue filter to manipulate the color of
the menu bar.  This may cause some menu bar apps to display with strange
colors (particularly those that use colored icons or graphs in the menu
bar).  If you don't like this, you can disable the hue filter and
instead use a saturation filter to reduce the saturation, brightness and
contrast of the menu bar.

You will need to restart MenuBarFilter for this to take effect:

```shell
defaults write org.wezfurlong.MenuBarFilter useHue NO
```

## License

This software is distributed under the terms of the
[Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)

* Copyright 2005 Blacktree
* Copyright 2011 eece
* Copyright 2012 Wez Furlong
* Copyright 2014 Glenn Smith

