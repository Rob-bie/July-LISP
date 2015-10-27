## July

###### What is july?

*July is an experimental, interpretted, lexically-scoped Lisp dialect built in pure Elixir. While not suitable for solving large, real world problems; it is a joy to use for solving tiny problems and great fun to hack on. July is heavily inspired by Scheme, Clojure and Elixir.*

###### What does it look like?
```
(import 'math)
(import 'coll)

(defun fizzbuzz [n]
  (match (list (mod-0? n 5) (mod-0? n 3))
    [(#t #t)  'fizzbuzz]
    [(#f #t)  'fizz]
    [(#t #f)  'buzz]
    [_ n]))

[|>
  (range 1 100)
  (map fizzbuzz)]
```
<p align="center"><i>Solves the classic "FizzBuzz" problem for integers 1-100</i></p>

## Table of contents


- [Installation](#installation)
- [Jump into July](#a-peek-at-july)
	- [Primitives](#primitives)
	- [Functions](#functions)
		- [Def](#def)
		- [Fun](#fun)
		- [Defun](#defun)
		- [Closures](#closures)
		- [|>](#composing)
	- [A few special forms](#special)
		- [List](#list)
		- [Show](#show)
		-  [<>](#concat)
	- [Import](#import)
	- [Constructs (a few more special forms)](#constructs)
		- [If](#if)
		- [Cond](#cond)
		- [Match](#match)
		- [Let](#let)
- [TODO](#todo)
- [License](#license)

## Installation

<p align="center"><i>Requires Erlang 17+ and Elixir 1.1+ to be installed and on your path!</i></p>

July is still in it's infancy and there's no de facto way to get it up and running. There's currently three options:

1. Launching the REPL and evaluating files through the provided escript (*recommended*)
2. Launching the REPL in IEx and evaluating files inside the REPL
3. Directly invoking the evaluator

Regardless of what option you choose, you're going to need to clone the repository and jump to the directory:

```
git clone https://github.com/Rob-bie/July
cd dir
```

*Launching the REPL and evaluating files through the provided escript*

```
july
july "path-to-file.july"
```

or

```
escript july
escript july "path-to-file.july"
```

*Launching the REPL in IEx and evaluating files inside the REPL*

```
IEx -S mix
iex(1)> July.Repl.JulyRepl.start_repl
july@repl(1)> (eval-file "path-to-file.july")
```

*Directly invoking the evaluator*

```
IEx -S mix
iex(1)> July.Evaluator.eval("(eval-file \"path-to-file.july\")")
```

## Jump into July
...
