# Gala Window Manager Alternative Window Switcher

This is an alternative to the stock libplank window switcher.

### Current status

**Warning!** This is still very alpha and in progress.

The plugin uses an unreleased Gala API for plugins.
Until it is ready, the project status will not change.

## Hacking

You will need the most recent snapshot of gala project from bzr.

Inside the repo, you will need to create a new folder in the `plugins`
folder and symlink the `Makefile.am` and `src/Main.vala` files.

Now update the gala `plugins/Makefile.am` and append the new plugin folder to
the `SUBDIRS` variable.

And update the gala `configure.ac` file to include the new path
`plugins/alternate-alt-tab/Makefile` in its `AC_CONFIG_FILES`.

Last thing you will need to install the schema file.
You can just symlink the file and run `glib-compile-schemas`.

Next, continue with the normal gala build instructions.

```bash
$ ./autogen.sh --prefix=$PWD/build
$ make
$ make install
```


### Testing

Running gala directly from `./build/bin/gala` could result into a broken desktop.
To avoid this, consider using `Xephyr` (`apt-get install xerver-xephyr`).

You will need to start Xephyr and tell gala to use it.

```bash
$ Xepyr :1 &
$ ./build/bin/gala -d :1 &
```

Note: `:1` is just an ID, it can be a different number if **1** is already
being used. Consider increasing the number.

Now that you have gala build running in a virtual X server, you can launch
applications with the `DISPLAY=:1` environment variable set.

```bash
$ DISPLAY=:1 xterm &
```

Now switching to the Xephyr window, you can capture the mouse and keyboard and
test your build.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
