the Ultimate Magic (the Gathering) Trading System
=============================
Getting Started
---------------
Here are some general pointers to get started with development.

**1. (once)** Get a copy of the MagicDB folder from Magic Assistant, or [download a copy](http://dl.dropbox.com/u/2243552/MagicDB.tar.gz) and unpack it into the **site/** directory.

**2. (once)** Link or copy library files from nitrogen to site directory.
    ln -s nitrogen/deps/nitrogen_core/www/ site/static/nitrogen

**3. (once)** Initialize and update the submodules, this will download Nitrogen from GitHub.
    git submodule init
    git submodule update

**4.** Start Erlang on your system with the correct path.
    erl -sname umts -pa "../nitrogen/apps/nitrogen/ebin" -pa "../nitrogen/apps/simple_bridge/ebin" -pa "../nitrogen/apps/nprocreg/ebin" -pa "./ebin"
    cd(<path to site/ directory>).

**5. (once)** Compile sync module from Nitrogen so it can be executed, a simple module that runs all make-files it can find.
    c("../nitrogen/apps/nitrogen/src/sync.erl", [{i, "../nitrogen/apps/nitrogen/include"}]).

**6.** Execute sync, this will compile the rest of the applications. Use this script when you have modified some source.
    sync:go().

**7.** Start the required applications.
    lists:foreach(fun application:start/1, [sasl, nprocreg, umts]).

**8. (once)** Create the Mnesia schema and tables.
    umts_db:reinstall().

**9. (once)** Parse the Magic Assistant database into Mnesia.
    umts_parser:parse().

**10. ** Profit! You should now be able to navigate to **http://127.0.0.1:8000** and start trading!

Resources
---------
This project currently depends on the cards database parsed by [Magic Assistant](https://sourceforge.net/projects/mtgbrowser/) an awsome MTG deck manager.

This web application is built on [Nitrogen](http://nitrogenproject.com), the sexy web-framework developed in [Erlang](http://www.erlang.org).