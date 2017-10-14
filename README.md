# CBStream parser for XChat and HexChat #

CBStream Xchat / HexChat plugin - Handle all the weirdnesses of the 
IRC-to-ChatterBox bridge that is FreeNode's #cbstream

# Installation #

First, install the required modules.  (See the top of the file for the use
statements.)

Next, copy this file to your Xchat directory.  For me, that is ~/.xchat2 for
XChat and ~/.config/hexchat/addons for HexChat. YMMV, especially on Windows.  
The file should be named 'cbstream.pl', though only the extention is
important.

Then create a configuration file called "cbstream.yaml".  With XChat, this
goes in the same directory as above, for HexChat, it seems to be one directory
up.

It should look like:

```
    ---
    cbstream: 
      pmpassword: myreallylongpasswordthatIshouldneverforget
      pmuser: Tanktalus
```

That's the minimal configuration required.  Now load the plugin (I think
this happens automatically on Xchat's start-up, but you can do it manually
with the /load command).  You're ready to go.

# Configuration Options #

Other than pmpassword and pmuser, other options include:

- item nick-prefix
- item nick-suffix

Here you can customise how the nicks will appear in Xchat.  I set these this
way:

```
    cbstream:
      nick-prefix: "["
      nick-suffix: "]"
```

Then nicks will show up like "[tye]" instead of just "tye".  This makes it
easier for cut&paste for me.

- item ignore_mode

If you have anyone being ignored, you can actually be told when you receive
a message from them.  You can set this mode to C<brief> to get a notice
that a message has been ignored (and from whom), or C<verbose> to not only
get the notice, but the entire message they sent.


# What it does #

By default, it replaces the nick 'cbstream' on the left of the line in Xchat
with the real nick (see nick-prefix and nick-suffix above).  It also enables
some new commands:

## Commands ##

### `/cblog` ###

This will do a quick login with the cbstream server, joining the #cbstream-login
channel, posting your plogin command, and then closing the tabs.  You may
not end up back in the channel you started from.

You only need to do this whenever cbstream is restarted, not just any time
you join IRC.  You still need to be registered with FreeNode's NickServ.

### `/cbig` ###

This will reload the /ignore's from PerlMonks to be used in IRC.  Transfering
back and forth is NOT automatic, and would cause undue stress on the PM
server, slowing down your IRC experience.

When you run this command, your system will retrieve your ignore list from
Perlmonks, and then resolve each user number to a name.  This lookup will
use a local cache to avoid hitting the server too much for each number to name
lookup.  This also means that if you unignore on Perlmonks, the user may
still show up in the cbstream->ignore->byid fields in your conf file.  This
is normal and won't interfere with anything.

### `/cbignore` ###

This will add an ignore, and save it to your PM user for use with other
CB applications (such as Full Page Chat).


### `/cbunignore` ###

This will remove an ignore, and remove it from your PM user as well.

### `/cbmsg ###

This will send a /msg to whomever you specify.  Any private response will
not be seen in IRC.

### `/cbset` ###

This will set a configuration value.  Note that there's no validation here:
you can set anything you want.

```
/cbset foo bar
```

This will persist via the config file for future use.

### `/cbget` ###

This will retrieve a configuration value from the config file.

### `/cbrm` ###

This will remove a configuration key from the config file.

# TODO #

- validation for cbset - ensuring you're setting real keys to allowed values





