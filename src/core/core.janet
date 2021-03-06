# The core janet library
# Copyright 2019 (C) Calvin Rose

###
###
### Macros and Basic Functions
###
###

(var *env* "The current environment." _env)

(def defn :macro
  "(def name & more)\n\nDefine a function. Equivalent to (def name (fn name [args] ...))."
  (fn defn [name & more]
    (def len (length more))
    (def modifiers @[])
    (var docstr "")
    (def fstart
      (fn recur [i]
        (def {i ith} more)
        (def t (type ith))
        (if (= t :tuple)
          i
          (do
            (if (= t :string)
              (set docstr ith)
              (array/push modifiers ith))
            (if (< i len) (recur (+ i 1)))))))
    (def start (fstart 0))
    (def args (get more start))
    # Add function signature to docstring
    (var index 0)
    (def arglen (length args))
    (def buf (buffer "(" name))
    (while (< index arglen)
      (buffer/push-string buf " ")
      (buffer/format buf "%p" (get args index))
      (set index (+ index 1)))
    (array/push modifiers (string buf ")\n\n" docstr))
    # Build return value
    ~(def ,name ,;modifiers (fn ,name ,;(tuple/slice more start)))))

(defn defmacro :macro
  "Define a macro."
  [name & more]
  (apply defn name :macro more))

(defmacro defmacro-
  "Define a private macro that will not be exported."
  [name & more]
  (apply defn name :macro :private more))

(defmacro defn-
  "Define a private function that will not be exported."
  [name & more]
  (apply defn name :private more))

(defmacro def-
  "Define a private value that will not be exported."
  [name & more]
  ~(def ,name :private ,;more))

(defn defglobal
  "Dynamically create a global def."
  [name value]
  (def name* (symbol name))
  (put *env* name* @{:value value})
  nil)

(defn varglobal
  "Dynamically create a global var."
  [name init]
  (def name* (symbol name))
  (put *env* name* @{:ref @[init]})
  nil)

# Basic predicates
(defn even? "Check if x is even." [x] (== 0 (% x 2)))
(defn odd? "Check if x is odd." [x] (not= 0 (% x 2)))
(defn zero? "Check if x is zero." [x] (== x 0))
(defn pos? "Check if x is greater than 0." [x] (> x 0))
(defn neg? "Check if x is less than 0." [x] (< x 0))
(defn one? "Check if x is equal to 1." [x] (== x 1))
(defn number? "Check if x is a number." [x] (= (type x) :number))
(defn fiber? "Check if x is a fiber." [x] (= (type x) :fiber))
(defn string? "Check if x is a string." [x] (= (type x) :string))
(defn symbol? "Check if x is a symbol." [x] (= (type x) :symbol))
(defn keyword? "Check if x is a keyword." [x] (= (type x) :keyword))
(defn buffer? "Check if x is a buffer." [x] (= (type x) :buffer))
(defn function? "Check if x is a function (not a cfunction)." [x]
  (= (type x) :function))
(defn cfunction? "Check if x a cfunction." [x] (= (type x) :cfunction))
(defn table? "Check if x a table." [x] (= (type x) :table))
(defn struct? "Check if x a struct." [x] (= (type x) :struct))
(defn array? "Check if x is an array." [x] (= (type x) :array))
(defn tuple? "Check if x is a tuple." [x] (= (type x) :tuple))
(defn boolean? "Check if x is a boolean." [x] (= (type x) :boolean))
(defn bytes? "Check if x is a string, symbol, or buffer." [x]
  (def t (type x))
  (if (= t :string) true (if (= t :symbol) true (if (= t :keyword) true (= t :buffer)))))
(defn dictionary? "Check if x a table or struct." [x]
  (def t (type x))
  (if (= t :table) true (= t :struct)))
(defn indexed? "Check if x is an array or tuple." [x]
  (def t (type x))
  (if (= t :array) true (= t :tuple)))
(defn true? "Check if x is true." [x] (= x true))
(defn false? "Check if x is false." [x] (= x false))
(defn nil? "Check if x is nil." [x] (= x nil))
(defn empty? "Check if xs is empty." [xs] (= 0 (length xs)))
(def idempotent?
  "(idempotent? x)\n\nCheck if x is a value that evaluates to itself when compiled."
  (do
    (def non-atomic-types
      {:array true
       :tuple true
       :table true
       :buffer true
       :struct true})
    (fn idempotent? [x] (not (get non-atomic-types (type x))))))

# C style macros and functions for imperative sugar. No bitwise though.
(defn inc "Returns x + 1." [x] (+ x 1))
(defn dec "Returns x - 1." [x] (- x 1))
(defmacro ++ "Increments the var x by 1." [x] ~(set ,x (,+ ,x ,1)))
(defmacro -- "Decrements the var x by 1." [x] ~(set ,x (,- ,x ,1)))
(defmacro += "Increments the var x by n." [x n] ~(set ,x (,+ ,x ,n)))
(defmacro -= "Decrements the var x by n." [x n] ~(set ,x (,- ,x ,n)))
(defmacro *= "Shorthand for (set x (* x n))." [x n] ~(set ,x (,* ,x ,n)))
(defmacro /= "Shorthand for (set x (/ x n))." [x n] ~(set ,x (,/ ,x ,n)))
(defmacro %= "Shorthand for (set x (% x n))." [x n] ~(set ,x (,% ,x ,n)))

(defmacro default
  "Define a default value for an optional argument.
  Expands to (def sym (if (= nil sym) val sym))"
  [sym val]
  ~(def ,sym (if (= nil ,sym) ,val ,sym)))

(defmacro comment
  "Ignores the body of the comment."
  [])

(defmacro if-not
  "Shorthand for (if (not ... "
  [condition exp-1 &opt exp-2]
  ~(if ,condition ,exp-2 ,exp-1))

(defmacro when
  "Evaluates the body when the condition is true. Otherwise returns nil."
  [condition & body]
  ~(if ,condition (do ,;body)))

(defmacro unless
  "Shorthand for (when (not ... "
  [condition & body]
  ~(if ,condition nil (do ,;body)))

(defmacro cond
  "Evaluates conditions sequentially until the first true condition
  is found, and then executes the corresponding body. If there are an
  odd number of forms, the last expression is executed if no forms
  are matched. If there are no matches, return nil."
  [& pairs]
  (defn aux [i]
    (def restlen (- (length pairs) i))
    (if (= restlen 0) nil
      (if (= restlen 1) (get pairs i)
        (tuple 'if (get pairs i)
               (get pairs (+ i 1))
               (aux (+ i 2))))))
  (aux 0))

(defmacro case
  "Select the body that equals the dispatch value. When pairs
  has an odd number of arguments, the last is the default expression.
  If no match is found, returns nil"
  [dispatch & pairs]
  (def atm (idempotent? dispatch))
  (def sym (if atm dispatch (gensym)))
  (defn aux [i]
    (def restlen (- (length pairs) i))
    (if (= restlen 0) nil
      (if (= restlen 1) (get pairs i)
        (tuple 'if (tuple = sym (get pairs i))
               (get pairs (+ i 1))
               (aux (+ i 2))))))
  (if atm
    (aux 0)
    (tuple 'do
           (tuple 'def sym dispatch)
           (aux 0))))

(defmacro let
  "Create a scope and bind values to symbols. Each pair in bindings is
  assigned as if with def, and the body of the let form returns the last
  value."
  [bindings & body]
  (if (odd? (length bindings)) (error "expected even number of bindings to let"))
  (def len (length bindings))
  (var i 0)
  (var accum @['do])
  (while (< i len)
    (def {i k (+ i 1) v} bindings)
    (array/push accum (tuple 'def k v))
    (+= i 2))
  (array/concat accum body)
  (tuple/slice accum 0))

(defmacro try
  "Try something and catch errors. Body is any expression,
  and catch should be a form with the first element a tuple. This tuple
  should contain a binding for errors and an optional binding for
  the fiber wrapping the body. Returns the result of body if no error,
  or the result of catch if an error."
  [body catch]
  (let [[[err fib]] catch
        f (gensym)
        r (gensym)]
    ~(let [,f (,fiber/new (fn [] ,body) :e)
           ,r (resume ,f)]
       (if (= (,fiber/status ,f) :error)
         (do (def ,err ,r) ,(if fib ~(def ,fib ,f)) ,;(tuple/slice catch 1))
         ,r))))

(defmacro and
  "Evaluates to the last argument if all preceding elements are true, otherwise
  evaluates to false."
  [& forms]
  (var ret true)
  (def len (length forms))
  (var i len)
  (while (> i 0)
    (-- i)
    (set ret (if (= ret true)
               (get forms i)
               (tuple 'if (get forms i) ret))))
  ret)

(defmacro or
  "Evaluates to the last argument if all preceding elements are false, otherwise
  evaluates to true."
  [& forms]
  (var ret nil)
  (def len (length forms))
  (var i len)
  (while (> i 0)
    (-- i)
    (def fi (get forms i))
    (set ret (if (idempotent? fi)
               (tuple 'if fi fi ret)
               (do
                 (def $fi (gensym))
                 (tuple 'do (tuple 'def $fi fi)
                        (tuple 'if $fi $fi ret))))))
  ret)

(defmacro with-syms
  "Evaluates body with each symbol in syms bound to a generated, unique symbol."
  [syms & body]
  (var i 0)
  (def len (length syms))
  (def accum @[])
  (while (< i len)
    (array/push accum (get syms i) [gensym])
    (++ i))
  ~(let (,;accum) ,;body))

(defn- for-template
  [binding start stop step comparison delta body]
  (with-syms [i s]
    ~(do
       (var ,i ,start)
       (def ,s ,stop)
       (while (,comparison ,i ,s)
         (def ,binding ,i)
         ,;body
         (set ,i (,delta ,i ,step))))))

(defn- each-template
  [binding in body]
  (with-syms [i len]
    (def ds (if (idempotent? in) in (gensym)))
    ~(do
       (var ,i 0)
       ,(unless (= ds in) ~(def ,ds ,in))
       (def ,len (,length ,ds))
       (while (,< ,i ,len)
         (def ,binding (get ,ds ,i))
         ,;body
         (++ ,i)))))

(defn- keys-template
  [binding in pair? body]
  (with-syms [k]
    (def ds (if (idempotent? in) in (gensym)))
    ~(do
       ,(unless (= ds in) ~(def ,ds ,in))
       (var ,k (,next ,ds nil))
       (while ,k
         (def ,binding ,(if pair? ~(tuple ,k (get ,ds ,k)) k))
         ,;body
         (set ,k (,next ,ds ,k))))))

(defn- iterate-template
  [binding expr body]
  (with-syms [i]
    ~(do
       (var ,i nil)
       (while (set ,i ,expr)
         ,body))))

(defn- loop1
  [body head i]

  (def {i binding
        (+ i 1) verb
        (+ i 2) object} head)

  (cond

    # Terminate recursion
    (<= (length head) i)
    ~(do ,;body)

    # 2 term expression
    (keyword? binding)
    (let [rest (loop1 body head (+ i 2))]
      (case binding
        :while ~(do (if ,verb nil (break)) ,rest)
        :let ~(let ,verb (do ,rest))
        :after ~(do ,rest ,verb nil)
        :before ~(do ,verb ,rest nil)
        :repeat (with-syms [iter]
                  ~(do (var ,iter ,verb) (while (> ,iter 0) ,rest (-- ,iter))))
        :when ~(when ,verb ,rest)
        (error (string "unexpected loop modifier " binding))))

    # 3 term expression
    (let [rest (loop1 body head (+ i 3))]
      (case verb
        :range (let [[start stop step] object]
                 (for-template binding start stop (or step 1) < + [rest]))
        :keys (keys-template binding object false [rest])
        :pairs (keys-template binding object true [rest])
        :down (let [[start stop step] object]
                (for-template binding start stop (or step 1) > - [rest]))
        :in (each-template binding object [rest])
        :iterate (iterate-template binding object rest)
        :generate (with-syms [f s]
                    ~(let [,f ,object]
                       (while true
                         (def ,binding (,resume ,f))
                         (if (= :dead (,fiber/status ,f)) (break))
                         ,rest)))
        (error (string "unexpected loop verb " verb))))))

(defmacro for
  "Do a c style for loop for side effects. Returns nil."
  [i start stop & body]
  (for-template i start stop 1 < + body))

(defmacro each
  "Loop over each value in ind. Returns nil."
  [x ind & body]
  (each-template x ind body))

(defmacro loop
  "A general purpose loop macro. This macro is similar to the Common Lisp
  loop macro, although intentionally much smaller in scope.
  The head of the loop should be a tuple that contains a sequence of
  either bindings or conditionals. A binding is a sequence of three values
  that define something to loop over. They are formatted like:\n\n
  \tbinding :verb object/expression\n\n
  Where binding is a binding as passed to def, :verb is one of a set of keywords,
  and object is any janet expression. The available verbs are:\n\n
  \t:iterate - repeatedly evaluate and bind to the expression while it is truthy.\n
  \t:range - loop over a range. The object should be two element tuple with a start
  and end value, and an optional postive step. The range is half open, [start, end).\n
  \t:down - Same as range, but loops in reverse.\n
  \t:keys - Iterate over the keys in a data structure.\n
  \t:pairs - Iterate over the keys value pairs in a data structure.\n
  \t:in - Iterate over the values in an indexed data structure or byte sequence.\n
  \t:generate - Iterate over values yielded from a fiber. Can be paired with the generator
  function for the producer/consumer pattern.\n\n
  loop also accepts conditionals to refine the looping further. Conditionals are of
  the form:\n\n
  \t:modifier argument\n\n
  where :modifier is one of a set of keywords, and argument is keyword dependent.
  :modifier can be one of:\n\n
  \t:while expression - breaks from the loop if expression is falsey.\n
  \t:let bindings - defines bindings inside the loop as passed to the let macro.\n
  \t:before form - evaluates a form for a side effect before of the next inner loop.\n
  \t:after form - same as :before, but the side effect happens after the next inner loop.\n
  \t:repeat n - repeats the next inner loop n times.\n
  \t:when condition - only evaluates the loop body when condition is true.\n\n
  The loop macro always evaluates to nil."
  [head & body]
  (loop1 body head 0))

(put _env 'loop1 nil)
(put _env 'for-template nil)
(put _env 'iterate-template nil)
(put _env 'each-template nil)
(put _env 'keys-template nil)

(defmacro seq
  "Similar to loop, but accumulates the loop body into an array and returns that.
  See loop for details."
  [head & body]
  (def $accum (gensym))
  ~(do (def ,$accum @[]) (loop ,head (array/push ,$accum (do ,;body))) ,$accum))

(defmacro generate
  "Create a generator expression using the loop syntax. Returns a fiber
  that yields all values inside the loop in order. See loop for details."
  [head & body]
  ~(fiber/new (fn [] (loop ,head (yield (do ,;body))))))

(defmacro coro
  "A wrapper for making fibers. Same as (fiber/new (fn [] ...body))."
  [& body]
  (tuple fiber/new (tuple 'fn '[] ;body)))

(defn sum
  "Returns the sum of xs. If xs is empty, returns 0."
  [xs]
  (var accum 0)
  (each x xs (+= accum x))
  accum)

(defn product
  "Returns the product of xs. If xs is empty, returns 1."
  [xs]
  (var accum 1)
  (each x xs (*= accum x))
  accum)

(defmacro if-let
  "Make multiple bindings, and if all are truthy,
  evaluate the tru form. If any are false or nil, evaluate
  the fal form. Bindings have the same syntax as the let macro."
  [bindings tru &opt fal]
  (def len (length bindings))
  (if (zero? len) (error "expected at least 1 binding"))
  (if (odd? len) (error "expected an even number of bindings"))
  (defn aux [i]
    (def bl (get bindings i))
    (def br (get bindings (+ 1 i)))
    (if (>= i len)
      tru
      (do
        (def atm (idempotent? bl))
        (def sym (if atm bl (gensym)))
        (if atm
          # Simple binding
          (tuple 'do
                 (tuple 'def sym br)
                 (tuple 'if sym (aux (+ 2 i)) fal))
          # Destructured binding
          (tuple 'do
                 (tuple 'def sym br)
                 (tuple 'if sym
                        (tuple 'do
                               (tuple 'def bl sym)
                               (aux (+ 2 i)))
                        fal))))))
  (aux 0))

(defmacro when-let
  "Same as (if-let bindings (do ;body))."
  [bindings & body]
  ~(if-let ,bindings (do ,;body)))

(defn comp
  "Takes multiple functions and returns a function that is the composition
  of those functions."
  [& functions]
  (case (length functions)
    0 nil
    1 (get functions 0)
    2 (let [[f g]       functions] (fn [x] (f (g x))))
    3 (let [[f g h]     functions] (fn [x] (f (g (h x)))))
    4 (let [[f g h i]   functions] (fn [x] (f (g (h (i x))))))
    (let [[f g h i j] functions]
      (comp (fn [x] (f (g (h (i (j x))))))
            ;(tuple/slice functions 5 -1)))))

(defn identity
  "A function that returns its first argument."
  [x]
  x)

(defn complement
  "Returns a function that is the complement to the argument."
  [f]
  (fn [x] (not (f x))))

(defn extreme
  "Returns the most extreme value in args based on the function order.
  order should take two values and return true or false (a comparison).
  Returns nil if args is empty."
  [order args]
  (var [ret] args)
  (each x args (if (order x ret) (set ret x)))
  ret)

(defn max
  "Returns the numeric maximum of the arguments."
  [& args] (extreme > args))

(defn min
  "Returns the numeric minimum of the arguments."
  [& args] (extreme < args))

(defn max-order
  "Returns the maximum of the arguments according to a total
  order over all values."
  [& args] (extreme order> args))

(defn min-order
  "Returns the minimum of the arguments according to a total
  order over all values."
  [& args] (extreme order< args))

(defn first
  "Get the first element from an indexed data structure."
  [xs]
  (get xs 0))

(defn last
  "Get the last element from an indexed data structure."
  [xs]
  (get xs (- (length xs) 1)))

###
###
### Indexed Combinators
###
###

(def sort
  "(sort xs [, by])\n\nSort an array in-place. Uses quick-sort and is not a stable sort."
  (do

    (defn partition
      [a lo hi by]
      (def pivot (get a hi))
      (var i lo)
      (for j lo hi
        (def aj (get a j))
        (when (by aj pivot)
          (def ai (get a i))
          (set (a i) aj)
          (set (a j) ai)
          (++ i)))
      (set (a hi) (get a i))
      (set (a i) pivot)
      i)

    (defn sort-help
      [a lo hi by]
      (when (> hi lo)
        (def piv (partition a lo hi by))
        (sort-help a lo (- piv 1) by)
        (sort-help a (+ piv 1) hi by))
      a)

    (fn sort [a &opt by]
      (sort-help a 0 (- (length a) 1) (or by order<)))))

(defn sorted
  "Returns a new sorted array without modifying the old one."
  [ind by]
  (sort (array/slice ind) by))

(defn reduce
  "Reduce, also know as fold-left in many languages, transforms
  an indexed type (array, tuple) with a function to produce a value."
  [f init ind]
  (var res init)
  (each x ind (set res (f res x)))
  res)

(defn map
  "Map a function over every element in an indexed data structure and
  return an array of the results."
  [f & inds]
  (def ninds (length inds))
  (if (= 0 ninds) (error "expected at least 1 indexed collection"))
  (var limit (length (get inds 0)))
  (for i 0 ninds
    (def l (length (get inds i)))
    (if (< l limit) (set limit l)))
  (def [i1 i2 i3 i4] inds)
  (def res (array/new limit))
  (case ninds
    1 (for i 0 limit (set (res i) (f (get i1 i))))
    2 (for i 0 limit (set (res i) (f (get i1 i) (get i2 i))))
    3 (for i 0 limit (set (res i) (f (get i1 i) (get i2 i) (get i3 i))))
    4 (for i 0 limit (set (res i) (f (get i1 i) (get i2 i) (get i3 i) (get i4 i))))
    (for i 0 limit
      (def args (array/new ninds))
      (for j 0 ninds (set (args j) (get (get inds j) i)))
      (set (res i) (f ;args))))
  res)

(defn mapcat
  "Map a function over every element in an array or tuple and
  use array to concatenate the results."
  [f ind]
  (def res @[])
  (each x ind
    (array/concat res (f x)))
  res)

(defn filter
  "Given a predicate, take only elements from an array or tuple for
  which (pred element) is truthy. Returns a new array."
  [pred ind]
  (def res @[])
  (each item ind
    (if (pred item)
      (array/push res item)))
  res)

(defn count
  "Count the number of items in ind for which (pred item)
  is true."
  [pred ind]
  (var counter 0)
  (each item ind
    (if (pred item)
      (++ counter)))
  counter)

(defn keep
  "Given a predicate, take only elements from an array or tuple for
  which (pred element) is truthy. Returns a new array of truthy predicate results."
  [pred ind]
  (def res @[])
  (each item ind
    (if-let [y (pred item)]
      (array/push res y)))
  res)

(defn range
  "Create an array of values [start, end) with a given step.
  With one argument returns a range [0, end). With two arguments, returns
  a range [start, end). With three, returns a range with optional step size."
  [& args]
  (case (length args)
    1 (do
        (def [n] args)
        (def arr (array/new n))
        (for i 0 n (put arr i i))
        arr)
    2 (do
        (def [n m] args)
        (def arr (array/new (- m n)))
        (for i n m (put arr (- i n) i))
        arr)
    3 (do
        (def [n m s] args)
        (if (neg? s)
          (seq [i :down [n m (- s)]] i)
          (seq [i :range [n m s]] i)))
    (error "expected 1 to 3 arguments to range")))

(defn find-index
  "Find the index of indexed type for which pred is true. Returns nil if not found."
  [pred ind]
  (def len (length ind))
  (var i 0)
  (var going true)
  (while (if (< i len) going)
    (def item (get ind i))
    (if (pred item) (set going false) (++ i)))
  (if going nil i))

(defn find
  "Find the first value in an indexed collection that satisfies a predicate. Returns
  nil if not found. Note their is no way to differentiate a nil from the indexed collection
  and a not found. Consider find-index if this is an issue."
  [pred ind]
  (def i (find-index pred ind))
  (if (= i nil) nil (get ind i)))

(defn take-until
  "Given a predicate, take only elements from an indexed type that satisfy
  the predicate, and abort on first failure. Returns a new array."
  [pred ind]
  (def i (find-index pred ind))
  (if i
    (array/slice ind 0 i)
    ind))

(defn take-while
  "Same as (take-until (complement pred) ind)."
  [pred ind]
  (take-until (complement pred) ind))

(defn drop-until
  "Given a predicate, remove elements from an indexed type that satisfy
  the predicate, and abort on first failure. Returns a new array."
  [pred ind]
  (def i (find-index pred ind))
  (if i
    (array/slice ind i)
    @[]))

(defn drop-while
  "Same as (drop-until (complement pred) ind)."
  [pred ind]
  (drop-until (complement pred) ind))

(defn juxt*
  "Returns the juxtaposition of functions. In other words,
  ((juxt* a b c) x) evaluates to ((a x) (b x) (c x))."
  [& funs]
  (fn [& args]
    (def ret @[])
    (each f funs
      (array/push ret (f ;args)))
    (tuple/slice ret 0)))

(defmacro juxt
  "Macro form of juxt*. Same behavior but more efficient."
  [& funs]
  (def parts @['tuple])
  (def $args (gensym))
  (each f funs
    (array/push parts (tuple apply f $args)))
  (tuple 'fn (tuple '& $args) (tuple/slice parts 0)))

(defmacro ->
  "Threading macro. Inserts x as the second value in the first form
  in forms, and inserts the modified first form into the second form
  in the same manner, and so on. Useful for expressing pipelines of data."
  [x & forms]
  (defn fop [last n]
    (def [h t] (if (= :tuple (type n))
                 (tuple (get n 0) (array/slice n 1))
                 (tuple n @[])))
    (def parts (array/concat @[h last] t))
    (tuple/slice parts 0))
  (reduce fop x forms))

(defmacro ->>
  "Threading macro. Inserts x as the last value in the first form
  in forms, and inserts the modified first form into the second form
  in the same manner, and so on. Useful for expressing pipelines of data."
  [x & forms]
  (defn fop [last n]
    (def [h t] (if (= :tuple (type n))
                 (tuple (get n 0) (array/slice n 1))
                 (tuple n @[])))
    (def parts (array/concat @[h] t @[last]))
    (tuple/slice parts 0))
  (reduce fop x forms))

(defmacro -?>
  "Short circuit threading macro. Inserts x as the last value in the first form
  in forms, and inserts the modified first form into the second form
  in the same manner, and so on. The pipeline will return nil
  if an intermediate value is nil.
  Useful for expressing pipelines of data."
  [x & forms]
  (defn fop [last n]
    (def [h t] (if (= :tuple (type n))
                 (tuple (get n 0) (array/slice n 1))
                 (tuple n @[])))
    (def sym (gensym))
    (def parts (array/concat @[h sym] t))
    ~(let [,sym ,last] (if ,sym ,(tuple/slice parts 0))))
  (reduce fop x forms))

(defmacro -?>>
  "Threading macro. Inserts x as the last value in the first form
  in forms, and inserts the modified first form into the second form
  in the same manner, and so on. The pipeline will return nil
  if an intermediate value is nil.
  Useful for expressing pipelines of data."
  [x & forms]
  (defn fop [last n]
    (def [h t] (if (= :tuple (type n))
                 (tuple (get n 0) (array/slice n 1))
                 (tuple n @[])))
    (def sym (gensym))
    (def parts (array/concat @[h] t @[sym]))
    ~(let [,sym ,last] (if ,sym ,(tuple/slice parts 0))))
  (reduce fop x forms))

(defn walk-ind [f form]
  (def len (length form))
  (def ret (array/new len))
  (each x form (array/push ret (f x)))
  ret)

(defn walk-dict [f form]
  (def ret @{})
  (loop [k :keys form]
    (put ret (f k) (f (get form k))))
  ret)

(defn walk
  "Iterate over the values in ast and apply f
  to them. Collect the results in a data structure . If ast is not a
  table, struct, array, or tuple,
  returns form."
  [f form]
  (case (type form)
    :table (walk-dict f form)
    :struct (table/to-struct (walk-dict f form))
    :array (walk-ind f form)
    :tuple (tuple/slice (walk-ind f form))
    form))

(put _env 'walk-ind nil)
(put _env 'walk-dict nil)

(defn postwalk
  "Do a post-order traversal of a data structure and call (f x)
  on every visitation."
  [f form]
  (f (walk (fn [x] (postwalk f x)) form)))

(defn prewalk
  "Similar to postwalk, but do pre-order traversal."
  [f form]
  (walk (fn [x] (prewalk f x)) (f form)))

(defmacro as->
  "Thread forms together, replacing as in forms with the value
  of the previous form. The first for is the value x. Returns the
  last value."
  [x as & forms]
  (var prev x)
  (each form forms
    (def sym (gensym))
    (def next-prev (postwalk (fn [y] (if (= y as) sym y)) form))
    (set prev ~(let [,sym ,prev] ,next-prev)))
  prev)

(defmacro as?->
  "Thread forms together, replacing as in forms with the value
  of the previous form. The first for is the value x. If any
  intermediate values are falsey, return nil; otherwise, returns the
  last value."
  [x as & forms]
  (var prev x)
  (each form forms
    (def sym (gensym))
    (def next-prev (postwalk (fn [y] (if (= y as) sym y)) form))
    (set prev ~(if-let [,sym ,prev] ,next-prev)))
  prev)

(defn partial
  "Partial function application."
  [f & more]
  (if (zero? (length more)) f
    (fn [& r] (f ;more ;r))))

(defn every?
  "Returns true if each value in is truthy, otherwise the first
  falsey value."
  [ind]
  (var res true)
  (loop [x :in ind :while res]
    (if x nil (set res x)))
  res)

(defn reverse
  "Reverses the order of the elements in a given array or tuple and returns a new array."
  [t]
  (def len (length t))
  (var n (dec len))
  (def reversed (array/new len))
  (while (>= n 0)
    (array/push reversed (get t n))
    (-- n))
  reversed)

(defn invert
  "Returns a table of where the keys of an associative data structure
  are the values, and the values of the keys. If multiple keys have the same
  value, one key will be ignored."
  [ds]
  (def ret @{})
  (loop [k :keys ds]
    (put ret (get ds k) k))
  ret)

(defn zipcoll
  "Creates a table from two arrays/tuples.
  Returns a new table."
  [keys vals]
  (def res @{})
  (def lk (length keys))
  (def lv (length vals))
  (def len (if (< lk lv) lk lv))
  (for i 0 len
    (put res (get keys i) (get vals i)))
  res)

(defn update
  "Accepts a key argument and passes its' associated value to a function.
  The key then, is associated to the function's return value"
  [ds key func & args]
  (def old (get ds key))
  (set (ds key) (func old ;args)))

(defn merge-into
  "Merges multiple tables/structs into a table. If a key appears in more than one
  collection, then later values replace any previous ones.
  Returns the original table."
  [tab & colls]
  (loop [c :in colls
         key :keys c]
    (set (tab key) (get c key)))
  tab)

(defn merge
  "Merges multiple tables/structs to one. If a key appears in more than one
  collection, then later values replace any previous ones.
  Returns a new table."
  [& colls]
  (def container @{})
  (loop [c :in colls
         key :keys c]
    (set (container key) (get c key)))
  container)

(defn keys
  "Get the keys of an associative data structure."
  [x]
  (def arr (array/new (length x)))
  (var k (next x nil))
  (while (not= nil k)
    (array/push arr k)
    (set k (next x k)))
  arr)

(defn values
  "Get the values of an associative data structure."
  [x]
  (def arr (array/new (length x)))
  (var k (next x nil))
  (while (not= nil k)
    (array/push arr (get x k))
    (set k (next x k)))
  arr)

(defn pairs
  "Get the values of an associative data structure."
  [x]
  (def arr (array/new (length x)))
  (var k (next x nil))
  (while (not= nil k)
    (array/push arr (tuple k (get x k)))
    (set k (next x k)))
  arr)

(defn frequencies
  "Get the number of occurrences of each value in a indexed structure."
  [ind]
  (def freqs @{})
  (each x ind
    (def n (get freqs x))
    (set (freqs x) (if n (+ 1 n) 1)))
  freqs)

(defn interleave
  "Returns an array of the first elements of each col,
  then the second, etc."
  [& cols]
  (def res @[])
  (def ncol (length cols))
  (when (> ncol 0)
    (def len (min ;(map length cols)))
    (loop [i :range [0 len]
           ci :range [0 ncol]]
      (array/push res (get (get cols ci) i))))
  res)

(defn distinct
  "Returns an array of the deduplicated values in xs."
  [xs]
  (def ret @[])
  (def seen @{})
  (each x xs (if (get seen x) nil (do (put seen x true) (array/push ret x))))
  ret)

(defn flatten-into
  "Takes a nested array (tree), and appends the depth first traversal of
  that array to an array 'into'. Returns array into."
  [into xs]
  (each x xs
    (if (indexed? x)
      (flatten-into into x)
      (array/push into x)))
  into)

(defn flatten
  "Takes a nested array (tree), and returns the depth first traversal of
  that array. Returns a new array."
  [xs]
  (flatten-into @[] xs))

(defn kvs
  "Takes a table or struct and returns and array of key value pairs
  like @[k v k v ...]. Returns a new array."
  [dict]
  (def ret (array/new (* 2 (length dict))))
  (loop [k :keys dict] (array/push ret k (get dict k)))
  ret)

(defn interpose
  "Returns a sequence of the elements of ind separated by
  sep. Returns a new array."
  [sep ind]
  (def len (length ind))
  (def ret (array/new (- (* 2 len) 1)))
  (if (> len 0) (put ret 0 (get ind 0)))
  (var i 1)
  (while (< i len)
    (array/push ret sep (get ind i))
    (++ i))
  ret)

(defn partition
  "Partition an indexed data structure into tuples
  of size n. Returns a new array."
  [n ind]
  (var i 0) (var nextn n)
  (def len (length ind))
  (def ret (array/new (math/ceil (/ len n))))
  (while (<= nextn len)
    (array/push ret (tuple/slice ind i nextn))
    (set i nextn)
    (+= nextn n))
  (if (not= i len) (array/push ret (tuple/slice ind i)))
  ret)

###
###
### IO Helpers
###
###

(defn slurp
  "Read all data from a file with name path
  and then close the file."
  [path]
  (def f (file/open path :r))
  (if-not f (error (string "could not open file " path)))
  (def contents (file/read f :all))
  (file/close f)
  contents)

(defn spit
  "Write contents to a file at path.
  Can optionally append to the file."
  [path contents &opt mode]
  (default mode :w)
  (def f (file/open path mode))
  (if-not f (error (string "could not open file " path " with mode " mode)))
  (file/write f contents)
  (file/close f)
  nil)

###
###
### Pattern Matching
###
###

(defmacro- with-idemp
  "Return janet code body that has been prepended
  with a binding of form to atom. If form is a non-idempotent
  form (a function call, etc.), make sure the resulting
  code will only evaluate once, even if body contains multiple
  copies of binding. In body, use binding instead of form."
  [binding form & body]
  (def $result (gensym))
  (def $form (gensym))
  ~(do
     (def ,$form ,form)
     (def ,binding (if (idempotent? ,$form) ,$form (gensym)))
     (def ,$result (do ,;body))
     (if (= ,$form ,binding)
       ,$result
       (tuple 'do (tuple 'def ,binding ,$form) ,$result))))


# Sentinel value for mismatches
(def- sentinel ~',(gensym))

(defn- match-1
  [pattern expr onmatch seen]
  (cond

    (symbol? pattern)
    (if (get seen pattern)
      ~(if (= ,pattern ,expr) ,(onmatch) ,sentinel)
      (do
        (put seen pattern true)
        ~(if (= nil (def ,pattern ,expr)) ,sentinel ,(onmatch))))

    (tuple? pattern)
    (match-1
      (get pattern 0) expr
      (fn []
        ~(if (and ,;(tuple/slice pattern 1)) ,(onmatch) ,sentinel)) seen)

    (array? pattern)
    (do
      (def len (length pattern))
      (var i -1)
      (with-idemp
        $arr expr
        ~(if (indexed? ,$arr)
           ,((fn aux []
               (++ i)
               (if (= i len)
                 (onmatch)
                 (match-1 (get pattern i) (tuple get $arr i) aux seen))))
           ,sentinel)))

    (dictionary? pattern)
    (do
      (var key nil)
      (with-idemp
        $dict expr
        ~(if (dictionary? ,$dict)
           ,((fn aux []
               (set key (next pattern key))
               (if (= key nil)
                 (onmatch)
                 (match-1 (get pattern key) (tuple get $dict key) aux seen))))
           ,sentinel)))

    :else ~(if (= ,pattern ,expr) ,(onmatch) ,sentinel)))

(defmacro match
  "Pattern matching. Match an expression x against
  any number of cases. Easy case is a pattern to match against, followed
  by an expression to evaluate to if that case is matched. A pattern that is
  a symbol will match anything, binding x's value to that symbol. An array
  will match only if all of it's elements match the corresponding elements in
  x. A table or struct will match if all values match with the corresponding
  values in x. A tuple pattern will match if it's first element matches, and the following
  elements are treated as predicates and are true. Any other value pattern will only
  match if it is equal to x."
  [x & cases]
  (with-idemp $x x
    (def len (length cases))
    (def len-1 (dec len))
    ((fn aux [i]
       (cond
         (= i len-1) (get cases i)
         (< i len-1) (with-syms [$res]
                       ~(if (= ,sentinel (def ,$res ,(match-1 (get cases i) $x (fn [] (get cases (inc i))) @{})))
                          ,(aux (+ 2 i))
                          ,$res)))) 0)))

(put _env 'sentinel nil)
(put _env 'match-1 nil)
(put _env 'with-idemp nil)

###
###
### Documentation
###
###

(var *doc-width*
  "Width in columns to print documentation."
  80)

(defn doc-format
  "Reformat text to wrap at a given line."
  [text]

  (def maxcol (- *doc-width* 8))
  (var buf @"    ")
  (var word @"")
  (var current 0)

  (defn pushword
    []
    (def oldcur current)
    (def spacer
      (if (<= maxcol (+ current (length word) 1))
        (do (set current 0) "\n    ")
        (do (++ current) " ")))
    (+= current (length word))
    (if (> oldcur 0)
      (buffer/push-string buf spacer))
    (buffer/push-string buf word)
    (buffer/clear word))

  (each b text
    (if (and (not= b 10) (not= b 32))
      (if (= b 9)
        (buffer/push-string word "  ")
        (buffer/push-byte word b))
      (do
        (if (> (length word) 0) (pushword))
        (when (= b 10)
          (buffer/push-string buf "\n    ")
          (set current 0)))))

  # Last word
  (pushword)

  buf)

(defn doc*
  "Get the documentation for a symbol in a given environment."
  [env sym]
  (def x (get env sym))
  (if (not x)
    (print "symbol " sym " not found.")
    (do
      (def bind-type
        (string "    "
                (cond
                  (x :ref) (string :var " (" (type (get (x :ref) 0)) ")")
                  (x :macro) :macro
                  (type (x :value)))
                "\n"))
      (def sm (x :source-map))
      (def d (x :doc))
      (print "\n\n"
             (if d bind-type "")
             (if-let [[path start end] sm] (string "    " path " (" start ":" end ")\n") "")
             (if (or d sm) "\n" "")
             (if d (doc-format d) "no documentation found.")
             "\n\n"))))

(defmacro doc
  "Shows documentation for the given symbol."
  [sym]
  ~(,doc* *env* ',sym))

###
###
### Macro Expansion
###
###

(defn macex1
  "Expand macros in a form, but do not recursively expand macros."
  [x]

  (defn dotable [t on-value]
    (def newt @{})
    (var key (next t nil))
    (while (not= nil key)
      (put newt (macex1 key) (on-value (get t key)))
      (set key (next t key)))
    newt)

  (defn expand-bindings [x]
    (case (type x)
      :array (map expand-bindings x)
      :tuple (tuple/slice (map expand-bindings x))
      :table (dotable x expand-bindings)
      :struct (table/to-struct (dotable x expand-bindings))
      (macex1 x)))

  (defn expanddef [t]
    (def last (get t (- (length t) 1)))
    (def bound (get t 1))
    (tuple/slice
      (array/concat
        @[(get t 0) (expand-bindings bound)]
        (tuple/slice t 2 -2)
        @[(macex1 last)])))

  (defn expandall [t]
    (def args (map macex1 (tuple/slice t 1)))
    (tuple (get t 0) ;args))

  (defn expandfn [t]
    (def t1 (get t 1))
    (if (symbol? t1)
      (do
        (def args (map macex1 (tuple/slice t 3)))
        (tuple 'fn t1 (get t 2) ;args))
      (do
        (def args (map macex1 (tuple/slice t 2)))
        (tuple 'fn t1 ;args))))

  (defn expandqq [t]
    (defn qq [x]
      (case (type x)
        :tuple (do
                 (def x0 (get x 0))
                 (if (or (= 'unquote x0) (= 'unquote-splicing x0))
                   (tuple x0 (macex1 (get x 1)))
                   (tuple/slice (map qq x))))
        :array (map qq x)
        :table (table (map qq (kvs x)))
        :struct (struct (map qq (kvs x)))
        x))
    (tuple (get t 0) (qq (get t 1))))

  (def specs
    {'set expanddef
     'def expanddef
     'do expandall
     'fn expandfn
     'if expandall
     'quote identity
     'quasiquote expandqq
     'var expanddef
     'while expandall})

  (defn dotup [t]
    (def h (get t 0))
    (def s (get specs h))
    (def entry (or (get *env* h) {}))
    (def m (entry :value))
    (def m? (entry :macro))
    (cond
      s (s t)
      m? (m ;(tuple/slice t 1))
      (tuple/slice (map macex1 t))))

  (def ret
    (case (type x)
      :tuple (if (= (tuple/type x) :brackets)
               (tuple/brackets ;(map macex1 x))
               (dotup x))
      :array (map macex1 x)
      :struct (table/to-struct (dotable x macex1))
      :table (dotable x macex1)
      x))
  ret)

(defn all
  "Returns true if all xs are truthy, otherwise the first false or nil value."
  [pred xs]
  (var ret true)
  (loop [x :in xs :while ret] (set ret (pred x)))
  ret)

(defn some
  "Returns false if all xs are false or nil, otherwise returns the first true value."
  [pred xs]
  (var ret nil)
  (loop [x :in xs :while (not ret)] (if-let [y (pred x)] (set ret y)))
  ret)

(defn deep-not=
  "Like not=, but mutable types (arrays, tables, buffers) are considered
  equal if they have identical structure. Much slower than not=."
  [x y]
  (def tx (type x))
  (or
    (not= tx (type y))
    (case tx
      :tuple (or (not= (length x) (length y)) (some identity (map deep-not= x y)))
      :array (or (not= (length x) (length y)) (some identity (map deep-not= x y)))
      :struct (deep-not= (pairs x) (pairs y))
      :table (deep-not= (table/to-struct x) (table/to-struct y))
      :buffer (not= (string x) (string y))
      (not= x y))))

(defn deep=
  "Like =, but mutable types (arrays, tables, buffers) are considered
  equal if they have identical structure. Much slower than =."
  [x y]
  (not (deep-not= x y)))

(defn macex
  "Expand macros completely."
  [x]
  (var previous x)
  (var current (macex1 x))
  (var counter 0)
  (while (deep-not= current previous)
    (if (> (++ counter) 200)
      (error "macro expansion too nested"))
    (set previous current)
    (set current (macex1 current)))
  current)

(defn pp
  "Pretty print to stdout."
  [x]
  (print (buffer/format @"" "%p" x)))

###
###
### Evaluation and Compilation
###
###

(defn make-env
  "Create a new environment table. The new environment
  will inherit bindings from the parent environment, but new
  bindings will not pollute the parent environment."
  [&opt parent]
  (def parent (if parent parent _env))
  (def newenv (table/setproto @{} parent))
  newenv)

(defn bad-parse
  "Default handler for a parse error."
  [p where]
  (file/write stderr
              "parse error in "
              where
              " around byte "
              (string (parser/where p))
              ": "
              (parser/error p)
              "\n"))

(defn bad-compile
  "Default handler for a compile error."
  [msg macrof where]
  (file/write stderr "compile error: " msg " while compiling " where "\n")
  (when macrof (debug/stacktrace macrof)))

(defn run-context
  "Run a context. This evaluates expressions of janet in an environment,
  and is encapsulates the parsing, compilation, and evaluation.
  opts is a table or struct of options. The options are as follows:\n\n\t
  :chunks - callback to read into a buffer - default is getline\n\t
  :on-parse-error - callback when parsing fails - default is bad-parse\n\t
  :env - the environment to compile against - default is *env*\n\t
  :source - string path of source for better errors - default is \"<anonymous>\"\n\t
  :on-compile-error - callback when compilation fails - default is bad-compile\n\t
  :on-status - callback when a value is evaluated - default is debug/stacktrace\n\t
  :fiber-flags - what flags to wrap the compilation fiber with. Default is :a."
  [opts]

  (def {:env env
        :chunks chunks
        :on-status onstatus
        :on-compile-error on-compile-error
        :on-parse-error on-parse-error
        :fiber-flags guard
        :source where} opts)
  (default env *env*)
  (default chunks getline)
  (default onstatus debug/stacktrace)
  (default on-compile-error bad-compile)
  (default on-parse-error bad-parse)
  (default where "<anonymous>")

  # Are we done yet?
  (var going true)

  # The parser object
  (def p (parser/new))

  # Evaluate 1 source form
  (defn eval1 [source]
    (var good true)
    (def f
      (fiber/new
        (fn []
          (def res (compile source env where))
          (if (= (type res) :function)
            (res)
            (do
              (set good false)
              (def {:error err :start start :end end :fiber errf} res)
              (def msg
                (if (<= 0 start)
                  (string err " at (" start ":" end ")")
                  err))
              (on-compile-error msg errf where))))
        (or guard :a)))
    (def res (resume f nil))
    (when good (if going (onstatus f res))))

  (def oldenv *env*)
  (set *env* env)

  # Run loop
  (def buf @"")
  (while going
    (buffer/clear buf)
    (chunks buf p)
    (var pindex 0)
    (var pstatus nil)
    (def len (length buf))
    (when (= len 0)
      (parser/eof p)
      (set going false))
    (while (> len pindex)
      (+= pindex (parser/consume p buf pindex))
      (while (parser/has-more p)
        (eval1 (parser/produce p)))
      (when (= (parser/status p) :error)
        (on-parse-error p where))))

  # Check final parser state
  (while (parser/has-more p)
    (eval1 (parser/produce p)))
  (when (= (parser/status p) :error)
    (on-parse-error p where))

  (set *env* oldenv)

  env)

(defn eval-string
  "Evaluates a string in the current environment. If more control over the
  environment is needed, use run-context."
  [str &opt env]
  (var state (string str))
  (defn chunks [buf _]
    (def ret state)
    (set state nil)
    (when ret
      (buffer/push-string buf str)
      (buffer/push-string buf "\n")))
  (var returnval nil)
  (run-context {:env env
                :chunks chunks
                :on-compile-error (fn [msg errf &]
                                    (error (string "compile error: " msg)))
                :on-parse-error (fn [p x]
                                  (error (string "parse error: " (parser/error p))))
                :fiber-flags :
                :on-status (fn [f val]
                             (if-not (= (fiber/status f) :dead)
                               (error val))
                             (set returnval val))
                :source "eval"})
  returnval)

(defn eval
  "Evaluates a form in the current environment. If more control over the
  environment is needed, use run-context."
  [form &opt env]
  (default env *env*)
  (def res (compile form env "eval"))
  (if (= (type res) :function)
    (res)
    (error (res :error))))

(defn make-image
  "Create an image from an environment returned by require.
  Returns the image source as a string."
  [env]
  (marshal env (invert (env-lookup _env))))

(defn load-image
  "The inverse operation to make-image. Returns an environment."
  [image]
  (unmarshal image (env-lookup _env)))

(def module/paths
  "The list of paths to look for modules. The following
  substitutions are preformed on each path. :sys: becomes
  module/*syspath*, :name: becomes the last part of the module
  name after the last /, and :all: is the module name literally.
  :native: becomes the dynamic library file extension, usually dll
  or so. Each element is a two element tuple, containing the path
  template and a keyword :source, :native, or :image indicating how
  require should load files found at these paths."
  @[["./:all:.janet" :source]
    ["./:all:/init.janet" :source]
    [":sys:/:all:.janet" :source]
    [":sys:/:all:/init.janet" :source]
    ["./:all:.:native:" :native]
    ["./:all:/:name:.:native:" :native]
    [":sys:/:all:.:native:" :native]
    [":sys:/:all:/:name:.:native:" :native]
    ["./:all:.jimage" :image]
    ["./:all:.:name:.jimage" :image]
    [":sys:/:all:.jimage" :image]
    [":sys:/:all:/:name:.jimage" :image]
    [":all:" :source]])

(var module/*syspath*
  "The path where globally installed libraries are located.
  The default is set at build time and is /usr/local/lib/janet on linux/posix, and
  on Windows is C:/Janet/Library."
  (or (os/getenv "JANET_PATH") ""))

(defn- fexists [path]
  (def f (file/open path))
  (if f (do (file/close f) path)))

(defn module/find
  "Try to match a module or path name from the patterns in module/paths.
  Returns a tuple (fullpath kind) where the kind is one of :source, :native,
  or image if the module is found, otherise a tuple with nil followed by
  an error message."
  [path]
  (def parts (string/split "/" path))
  (def name (get parts (- (length parts) 1)))
  (def nati (if (= :windows (os/which)) "dll" "so"))
  (defn make-full
    [[p mod-kind]]
    (def fullpath (->> p
                       (string/replace ":name:" name)
                       (string/replace ":sys:" module/*syspath*)
                       (string/replace ":native:" nati)
                       (string/replace ":all:" path)))
    [fullpath mod-kind])
  (defn check-path [x] (if (fexists (x 0)) x))
  (def paths (map make-full module/paths))
  (def res (find check-path paths))
  (if res res [nil (string "could not find module "
                           path
                           ":\n    "
                           ;(interpose "\n    " (map 0 paths)))]))

(put _env 'fexists nil)

(def module/cache
  "Table mapping loaded module identifiers to their environments."
  @{})

(def module/loading
  "Table mapping currently loading modules to true. Used to prevent
  circular dependencies."
  @{})

(defn require
  "Require a module with the given name. Will search all of the paths in
  module/paths, then the path as a raw file path. Returns the new environment
  returned from compiling and running the file."
  [path & args]
  (def {:exit exit-on-error} (table ;args))
  (if-let [check (get module/cache path)]
    check
    (do
      (def [fullpath mod-kind] (module/find path))
      (unless fullpath (error mod-kind))
      (def env
        (case mod-kind
          :source (do
                    # Normal janet module
                    (def f (file/open fullpath))
                    (def newenv (make-env))
                    (put module/loading fullpath true)
                    (defn chunks [buf _] (file/read f 2048 buf))
                    (defn bp [&opt x y]
                      (def ret (bad-parse x y))
                      (if exit-on-error (os/exit 1))
                      ret)
                    (defn bc [&opt x y z]
                      (def ret (bad-compile x y z))
                      (if exit-on-error (os/exit 1))
                      ret)
                    (run-context {:env newenv
                                  :chunks chunks
                                  :on-parse-error bp
                                  :on-compile-error bc
                                  :on-status (fn [f x]
                                               (when (not= (fiber/status f) :dead)
                                                 (debug/stacktrace f x)
                                                 (if exit-on-error (os/exit 1))))
                                  :source fullpath})
                    (file/close f)
                    (put module/loading fullpath nil)
                    (table/setproto newenv nil))
          :native (native fullpath (make-env))
          :image (load-image (slurp fullpath))))
      (put module/cache fullpath env)
      (put module/cache path env)
      env)))

(defn import*
  "Import a module into a given environment table. This is the
  functional form of (import ...) that expects and explicit environment
  table."
  [env path & args]
  (def {:as as
        :prefix prefix
        :export ep} (table ;args))
  (def newenv (require path ;args))
  (def prefix (or (and as (string as "/")) prefix (string path "/")))
  (loop [[k v] :pairs newenv :when (not (v :private))]
    (def newv (table/setproto @{:private (not ep)} v))
    (put env (symbol prefix k) newv)))

(defmacro import
  "Import a module. First requires the module, and then merges its
  symbols into the current environment, prepending a given prefix as needed.
  (use the :as or :prefix option to set a prefix). If no prefix is provided,
  use the name of the module as a prefix. One can also use :export true
  to re-export the imported symbols."
  [path & args]
  (def argm (map (fn [x]
                   (if (keyword? x)
                     x
                     (string x)))
                 args))
  (tuple import* '*env* (string path) ;argm))

(defn repl
  "Run a repl. The first parameter is an optional function to call to
  get a chunk of source code that should return nil for end of file.
  The second parameter is a function that is called when a signal is
  caught."
  [&opt chunks onsignal]
  (def newenv (make-env))
  (default onsignal (fn [f x]
                      (case (fiber/status f)
                        :dead (do
                                (put newenv '_ @{:value x})
                                (print (buffer/format @"" "%.20p" x)))
                        (debug/stacktrace f x))))
  (run-context {:env newenv
                :chunks chunks
                :on-status onsignal
                :source "repl"}))

(defmacro meta
  "Add metadata to the current environment."
  [& args]
  (def opts (table ;args))
  (loop [[k v] :pairs opts]
    (put *env* k v)))

(defn all-bindings
  "Get all symbols available in the current environment."
  [&opt env]
  (default env *env*)
  (def envs @[])
  (do (var e env) (while e (array/push envs e) (set e (table/getproto e))))
  (def symbol-set @{})
  (loop [envi :in envs
         k :keys envi
         :when (symbol? k)]
    (put symbol-set k true))
  (sort (keys symbol-set)))

# Use dynamic *env* from now on
(put _env '_env nil)
