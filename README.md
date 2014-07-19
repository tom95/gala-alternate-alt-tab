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

You will also need to symlink the `schema` file from plugin `data` folder
into the gala `data` folder.

Now update the gala `plugins/Makefile.am` and append the new plugin folder to
the `SUBDIRS` variable.

And update the gala `configure.ac` file to include the new path
`plugins/alternate-alt-tab/Makefile` in its `AC_CONFIG_FILES`.

Next, continue with the normal gala build instructions.


### Testing

Running gala directly from `src/gala` could result into a broken desktop.
To avoid this, consider using `Xephyr` (`apt-get install xerver-xephyr`).

You will need to start Xephyr and tell gala to use it.

```bash
$ Xepyr :1 &
$ ./src/gala -d :1 &
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
