# Magritte

Magritte is a shell language with a design firmly centered around pipes. The full specification can be found in [my thesis](http://files.jneen.net/academic/thesis.pdf).

The current repository represents an attempt to implement a JIT interpreter for Magritte using RPython. The Ruby interpreter mentioned in the paper can be found on the branch [old-implementation](https://github.com/prg-titech/magritte/tree/old-implementation).

Both implementations are still very unstable, so please do not use this code for anything critical.

## Building

* Depends on Ruby 2.6+ and Python 2.7 (yes, Python 2, it's required for RPython). There are no gem dependencies or Python package dependencies.

* There is, however, one submodule - make sure you have this fetched. Either `git clone --recursive` this repository, or run `git submodule update --init` in the project root.

* Run `make test` to compile and run the tests.

* Run `make test-dynamic` to run the tests without compiling, using python2 directly.

* After building, you can use ./bin/mag and ./bin/mag-dynamic to run magritte files directly.

## Architecture

The implementation is split into three parts:

* `lib/magc`, a compiler written in Ruby that generates Magritte bytecode
* `lib/magvm`, a virtual machine written in RPython, which interprets the bytecode
* `lib/mag`, the standard library, written in Magritte itself.

We don't plan on keeping the Ruby dependency - this currently only implements the frontend of the language, and once the language is stable enough we will rewrite those components in Magritte. The RPython is here to stay.

## `magc`

`magc` is a compiler frontend written in Ruby, consisting of a chain of transformations. The compiler pipeline is:

* `lexer.rb`: `Text -> Tokens`
* `skeleton.rb`: `Tokens -> Skeleton`
* `parser.rb`: `Skeleton -> AST` (AST is defined in `ast.rb`)
* `compiler.rb`: AST -> Bytecode

Running `magc my-file.mag` will generate two new files, `my-file.magc` and `my-file.magx`. The `.magc` file is the binary representation of the bytecode. The `.magx` file will contain a decompilation: a human-readable representation of the generated bytecode. These files are regenerated automatically if Magritte detects they are stale (i.e. older than the source file).

The instructions for the bytecode are documented in `lib/magvm/inst.py`.

A bytecode file consists of four sections:

* A list of all constant strings and numbers
* A list of all symbols in use
* A table of named labels for debugging purposes
* A list of all instructions and their integer arguments

The decompiled file does not contain the labels table, instead opting to mark the labels directly in the bytecode.

## `magvm`

`magvm` is an interpreter for the `magc` bytecode format. It is written in RPython, which is a subset of Python that can compile to native code. Because of this, it can be either run as a native binary (much faster), or run directly as Python code (much more flexible for debugging, doesn't require a slow compilation step).

Running `make test` will automatically compile the vm into `./bin/magvm`, and use it to run the test suite (`test/test.mag`). Running `make test-dynamic`, on the other hand, will not compile any RPython code, but instead run the interpreter as regular Python. `./bin/magvm-dynamic` and `./bin/mag-dynamic` do the same.

The machine (`machine.py`) is an object that keeps track of multiple Proc objects (`proc.py`), stepping each active process forward independently. Each process contains its own call stack, which is simply a list of Frame objects (`frame.py`). The frame implements a basic stack machine - instructions can push or pop values (`value.py`) from the current frame's stack.

A frame steps forward in the usual way, by incrementing the program counter and evaluating one instruction according to its action (`actions.py`). Instruction actions have full access to the frame, and can push/pop values, change the program counter (`jump` etc), and more.

Another way that native code can be run is through intrinsic functions (`intrinsic.py`), which are functions implemented in the VM itself, which can be called like normal Magritte functions. These use the syntax `@!intrinsic-name`, and are only available in files that declare `@allow-intrinsics` at the top-level. Currently the only file that does this is `lib/mag/prelude.mag`, which exports normal functions that use the intrinsics. Intrinsics also have full access to the frame and its process.

Some intrinsics, like `@!for` and `@!get`, cause a read or write on a channel. In this case, if there are no values ready in the channel, the process will change state to Proc.WAITING. This will cause it to be skipped over by the machine until the state changes.

This will most likely happen in the resolve phase: Periodically, the machine will perform handoffs of values between processes. This involves calling `.resolve()` on each channel (`channel.py`), which causes processes to be moved into the RUNNING or INTERRUPTED states.

## Debugging tools

You can enable debugging with the `MAGRITTE_DEBUG` environment variable. If set to 1 or 2, debug logs will go to stdout or stderr, respectively. If set to a file path, logs will be written to the specified file. The default is to write to `log/magritte.debug.log`.

Since the debug logs are a bit of a firehose, they are disabled by default. To enable them for a specific piece of Magritte code, use the Magritte functions `vm-debug on` and `vm-debug off` to control which piece of execution is being debugged.

Often it is necessary to further filter the logs, and for that we provide `./bin/log-filter`, which will filter a Magritte debug log according to specific "views":

* View channel registrations/deregistrations with `log-view channel -c <channel-id>`

* View only the activity of a single proc (as well as all resolve and check phases) with `log-view proc <proc-id>`, e.g. `log-view proc 2` to view only `<proc2>`.

When running in interpreted mode, you can use the intrinsic `@!vm-debugger` to drop to a Python shell, where you will have access to the current frame and any arguments you pass in. Using this in compiled mode results in a warning. This shell is also available elsewhere in the VM through the `open_shell` Python function from the `debug` module.
