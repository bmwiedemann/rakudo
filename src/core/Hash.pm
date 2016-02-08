my class Hash { # declared in BOOTSTRAP
    # my class Hash is Map {
    #     has Mu $!descriptor;

    multi method Hash() {
        self
    }

    multi method AT-KEY(Hash:D: Str:D \key) is raw {
        nqp::bindattr(self,Map,'$!storage',nqp::hash)
          unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
        nqp::ifnull(
          nqp::atkey(nqp::getattr(self,Map,'$!storage'),nqp::unbox_s(key)),
          nqp::p6bindattrinvres(
            (my \v := nqp::p6scalarfromdesc($!descriptor)),
            Scalar,
            '$!whence',
            -> { nqp::bindkey(
                   nqp::getattr(self,Map,'$!storage'),nqp::unbox_s(key),v) }
          )
        )
    }
    multi method AT-KEY(Hash:D: \key) is raw {
        nqp::bindattr(self,Map,'$!storage',nqp::hash)
          unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
        nqp::ifnull(
          nqp::atkey(nqp::getattr(self,Map,'$!storage'),nqp::unbox_s(key.Str)),
          nqp::p6bindattrinvres(
            (my \v := nqp::p6scalarfromdesc($!descriptor)),
            Scalar,
            '$!whence',
            -> { nqp::bindkey(
                   nqp::getattr(self,Map,'$!storage'),nqp::unbox_s(key.Str),v) }
          )
        )
    }

    multi method ASSIGN-KEY(Hash:D: Str:D \key, Mu \assignval) is raw {
        nqp::bindattr(self,Map,'$!storage',nqp::hash)
          unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
        my $storage := nqp::getattr(self,Map,'$!storage');
        my str $key = key;
        nqp::existskey($storage, $key)
            ?? (nqp::atkey($storage, $key) = assignval)
            !! nqp::bindkey($storage, $key,
                nqp::p6scalarfromdesc($!descriptor) = assignval)
    }
    multi method ASSIGN-KEY(Hash:D: \key, Mu \assignval) is raw {
        nqp::bindattr(self,Map,'$!storage',nqp::hash)
          unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
        my $storage := nqp::getattr(self,Map,'$!storage');
        my str $key = key.Str;
        nqp::existskey($storage, $key)
            ?? (nqp::atkey($storage, $key) = assignval)
            !! nqp::bindkey($storage, $key,
                nqp::p6scalarfromdesc($!descriptor) = assignval)
    }

    method BIND-KEY(Hash:D: \key, Mu \bindval) is raw {
        nqp::bindattr(self,Map,'$!storage',nqp::hash)
          unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
        nqp::bindkey(nqp::getattr(self,Map,'$!storage'),
          nqp::unbox_s(nqp::istype(key,Str) ?? key !! key.Str), bindval)
    }

    multi method perl(Hash:D \SELF:) {
        SELF.perlseen('Hash', {
            '$' x nqp::iscont(SELF)  # self is always deconted
            ~ '{' ~ self.pairs.sort.map({.perl}).join(', ') ~ '}'
        })
    }

    multi method gist(Hash:D:) {
        self.gistseen('Hash', {
            self.pairs.sort.map( -> $elem {
                given ++$ {
                    when 101 { '...' }
                    when 102 { last }
                    default  { $elem.gist }
                }
            } ).join: ', '
        })
    }

    multi method DUMP(Hash:D: :$indent-step = 4, :%ctx?) {
        return DUMP(self, :$indent-step) unless %ctx;

        my Mu $attrs := nqp::list();
        nqp::push($attrs, '$!descriptor');
        nqp::push($attrs,  $!descriptor );
        nqp::push($attrs, '$!storage'   );
        nqp::push($attrs,  nqp::getattr(nqp::decont(self), Map, '$!storage'));
        self.DUMP-OBJECT-ATTRS($attrs, :$indent-step, :%ctx);
    }

    method STORE_AT_KEY(\key, Mu \x --> Nil) {
        nqp::findmethod(Map,'STORE_AT_KEY')(self,key,
           nqp::p6scalarfromdesc($!descriptor) = x)
    }

    # introspection
    method name() {
        nqp::isnull($!descriptor) ?? Nil !! $!descriptor.name
    }
    method keyof() {
        Any
    }
    method of() {
        nqp::isnull($!descriptor) ?? Mu !! $!descriptor.of
    }
    method default() {
        nqp::isnull($!descriptor) ?? Any !! $!descriptor.default
    }
    method dynamic() {
        nqp::isnull($!descriptor) ?? Nil !! nqp::p6bool($!descriptor.dynamic)
    }

    multi method DELETE-KEY(Hash:U:) { Nil }
    multi method DELETE-KEY(Str() \key) {
        my Mu $val = self.AT-KEY(key);
        nqp::deletekey(
            nqp::getattr(self, Map, '$!storage'),
            nqp::unbox_s(key)
        );
        $val;
    }
    multi method DELETE-KEY(Str() \key, :$SINK! --> Nil) {
        nqp::deletekey(
            nqp::getattr(self, Map, '$!storage'),
            nqp::unbox_s(key)
        ) if nqp::defined(nqp::getattr(self,Map,'$!storage'))
    }

    method push(+values) {
        fail X::Cannot::Lazy.new(:action<push>, :what(self.^name))
          if values.is-lazy;
        my $previous;
        my int $has_previous = 0;
        for values -> $e {
            if $has_previous {
                self!_push_construct($previous, $e);
                $has_previous = 0;
            } elsif $e.^isa(Pair) {
                self!_push_construct($e.key, $e.value);
            } else {
                $previous = $e;
                $has_previous = 1;
            }
        }
        warn "Trailing item in Hash.push" if $has_previous;
        self
    }

    method append(+values) {
        fail X::Cannot::Lazy.new(:action<append>, :what(self.^name))
          if values.is-lazy;
        my $previous = 0;
        my int $has_previous;
        for values -> $e {
            if $has_previous {
                self!_append_construct($previous, $e);
                $has_previous = 0;
            } elsif $e.^isa(Pair) {
                self!_append_construct($e.key, $e.value);
            } else {
                $previous = $e;
                $has_previous = 1;
            }
        }
        warn "Trailing item in Hash.append" if $has_previous;
        self
    }

    proto method classify-list(|) { * }
    multi method classify-list( &test, \list, :&as ) {
        fail X::Cannot::Lazy.new(:action<classify>) if list.is-lazy;
        my \iter = (nqp::istype(list, Iterable) ?? list !! list.list).iterator;
        my $value := iter.pull-one;
        unless $value =:= IterationEnd {
            my $tested := test($value);

            # multi-level classify
            if nqp::istype($tested, Iterable) {
                loop {
                    my @keys  = $tested;
                    my $last := @keys.pop;
                    my $hash  = self;
                    $hash = $hash{$_} //= self.new for @keys;
                    nqp::push(
                      nqp::getattr(nqp::decont($hash{$last} //= []), List, '$!reified'),
                      &as ?? as($value) !! $value
                    );
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    $tested := test($value);
                };
            }

            # simple classify to store a specific value
            elsif &as {
                loop {
                    nqp::push(
                      nqp::getattr(nqp::decont(self{$tested} //= []), List, '$!reified'),
                      as($value)
                    );
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    $tested := test($value);
                };
            }

            # just a simple classify
            else {
                loop {
                    nqp::push(
                      nqp::getattr(nqp::decont(self{$tested} //= []), List, '$!reified'),
                      $value
                    );
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    $tested := test($value);
                };
            }
        }
        self;
    }
    multi method classify-list( %test, $list, |c ) {
        self.classify-list( { %test{$^a} }, $list, |c );
    }
    multi method classify-list( @test, $list, |c ) {
        self.classify-list( { @test[$^a] }, $list, |c );
    }

    proto method categorize-list(|) { * }
    # XXX GLR possibly more efficient taking an Iterable, not a @list
    # XXX GLR replace p6listitems op use
    # XXX GLR I came up with simple workarounds but this can probably
    #         be done more efficiently better.
    multi method categorize-list( &test, @list, :&as ) {
       fail X::Cannot::Lazy.new(:action<categorize>) if @list.is-lazy;
       if @list {
           # multi-level categorize
           if nqp::istype(test(@list[0])[0],Iterable) {
               @list.map: -> $l {
                   my $value := &as ?? as($l) !! $l;
                   for test($l) -> $k {
                       my @keys = @($k);
                       my $last := @keys.pop;
                       my $hash  = self;
                       $hash = $hash{$_} //= self.new for @keys;
                       $hash{$last}.push: $value;
                   }
               }
           } else {    
           # just a simple categorize
               @list.map: -> $l {
                  my $value := &as ?? as($l) !! $l;
                  (self{$_} //= []).push: $value for test($l);
               }
               # more efficient (maybe?) nom version that might
               # yet be updated for GLR
               # @list.map: -> $l {
               #     my $value := &as ?? as($l) !! $l;
               #     nqp::push(
               #       nqp::p6listitems(nqp::decont(self{$_} //= [])), $value )
               #       for test($l);
           }
       }
       self;
    }
    multi method categorize-list( %test, $list ) {
        self.categorize-list( { %test{$^a} }, $list );
    }
    multi method categorize-list( @test, $list ) {
        self.categorize-list( { @test[$^a] }, $list );
    }

    # push a value onto a hash slot, constructing an array if necessary
    method !_push_construct(Mu $key, Mu \value --> Nil) {
        self.EXISTS-KEY($key)
          ?? self.AT-KEY($key).^isa(Array)
            ?? self.AT-KEY($key).push(value)
            !! self.ASSIGN-KEY($key,[self.AT-KEY($key),value])
          !! self.ASSIGN-KEY($key,value)
    }

    # append values into a hash slot, constructing an array if necessary
    method !_append_construct(Mu $key, Mu \value --> Nil) {
        self.EXISTS-KEY($key)
          ?? self.AT-KEY($key).^isa(Array)
            ?? self.AT-KEY($key).append(|value)
            !! self.ASSIGN-KEY($key,[|self.AT-KEY($key),|value])
          !! self.ASSIGN-KEY($key,value)
    }

    my role TypedHash[::TValue] does Associative[TValue] {
        method AT-KEY(::?CLASS:D: Str() $key) is raw {
            self.EXISTS-KEY($key)
              ?? nqp::findmethod(Map,'AT-KEY')(self,$key)
              !! nqp::p6bindattrinvres(
                   (my \v := nqp::p6scalarfromdesc(nqp::getattr(self,Hash,'$!descriptor'))),
                   Scalar,
                   '$!whence',
                   -> { nqp::findmethod(Map,'STORE_AT_KEY')(self,$key,v) }
                 )
        }
        method STORE_AT_KEY(Str \key, TValue \x --> Nil) {
            nqp::findmethod(Map,'STORE_AT_KEY')(self,key,
              nqp::p6scalarfromdesc(nqp::getattr(self,Hash,'$!descriptor')) = x)
        }

        multi method ASSIGN-KEY(::?CLASS:D: Str:D \key, TValue \assignval) is raw {
            nqp::bindattr(self,Map,'$!storage',nqp::hash)
              unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
            my $storage := nqp::getattr(self,Map,'$!storage');
            my str $key = key;
            nqp::existskey($storage, $key)
              ?? (nqp::atkey($storage, $key) = assignval)
              !! nqp::bindkey($storage, $key,nqp::p6scalarfromdesc(
                   nqp::getattr(self,Hash,'$!descriptor')) = assignval)
        }
        multi method ASSIGN-KEY(::?CLASS:D: \key, TValue \assignval) is raw {
            nqp::bindattr(self,Map,'$!storage',nqp::hash)
              unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
            my $storage := nqp::getattr(self,Map,'$!storage');
            my str $key = key.Str;
            nqp::existskey($storage, $key)
              ?? (nqp::atkey($storage, $key) = assignval)
              !! nqp::bindkey($storage, $key,nqp::p6scalarfromdesc(
                   nqp::getattr(self,Hash,'$!descriptor')) = assignval)
        }

        method BIND-KEY(::?CLASS:D: \key, TValue \bindval) is raw {
            nqp::bindattr(self,Map,'$!storage',nqp::hash)
              unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
            nqp::bindkey(
                nqp::getattr(self, Map, '$!storage'),
                nqp::unbox_s(nqp::istype(key,Str) ?? key !! key.Str),
                bindval)
        }
        multi method perl(::?CLASS:D \SELF:) {
            SELF.perlseen('Hash', {
                '(my '
                ~ TValue.perl
                ~ ' % = ' ~ self.pairs.sort.map({.perl}).join(', ') ~ ')'
            })
        }
    }
    my role TypedHash[::TValue, ::TKey] does Associative[TValue] {
        has $!keys;
        method keyof () { TKey }
        method AT-KEY(::?CLASS:D: TKey \key) is raw {
            my str $which = key.WHICH;
            nqp::defined($!keys) && nqp::existskey($!keys,$which)
              ?? nqp::atkey(nqp::getattr(self,Map,'$!storage'),$which)
              !! nqp::p6bindattrinvres(
                   (my \v := nqp::p6scalarfromdesc(nqp::getattr(self,Hash,'$!descriptor'))),
                   Scalar,
                   '$!whence',
                   -> {
                     $!keys := nqp::hash unless nqp::defined($!keys);
                     nqp::bindkey($!keys,$which,key);
                     nqp::bindattr(self,Map,'$!storage',nqp::hash)
                       unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
                     nqp::bindkey(
                       nqp::getattr(self,Map,'$!storage'),$which,v);
                   }
                 )
        }

        method STORE_AT_KEY(TKey \key, TValue \x --> Nil) {
            my str $which = key.WHICH;
            $!keys := nqp::hash unless nqp::defined($!keys);
            nqp::bindkey($!keys,$which,key);

            nqp::bindattr(self,Map,'$!storage',nqp::hash)
              unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
            nqp::bindkey(
              nqp::getattr(self,Map,'$!storage'),$which,
              nqp::p6scalarfromdesc(nqp::getattr(self,Hash,'$!descriptor')) = x
            )
        }

        method ASSIGN-KEY(::?CLASS:D: TKey \key, TValue \assignval) {
            nqp::bindattr(self,Map,'$!storage',nqp::hash)
              unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
            my str $which = key.WHICH;
            if nqp::existskey(nqp::getattr(self,Map,'$!storage'),$which) {
                nqp::atkey(nqp::getattr(self,Map,'$!storage'),$which)
                  = assignval
            }
            else {
                $!keys := nqp::hash unless nqp::defined($!keys);
                nqp::bindkey($!keys,$which,key);
                nqp::bindkey(nqp::getattr(self,Map,'$!storage'),$which,
                  nqp::p6scalarfromdesc(nqp::getattr(self,Hash,'$!descriptor'))
                  = assignval)
            }
        }

        method BIND-KEY(TKey \key, TValue \bindval) is raw {
            $!keys := nqp::hash unless nqp::defined($!keys);
            nqp::bindattr(self,Map,'$!storage',nqp::hash)
              unless nqp::defined(nqp::getattr(self,Map,'$!storage'));
            my str $which = key.WHICH;
            nqp::bindkey($!keys,$which,key);
            nqp::bindkey(nqp::getattr(self,Map,'$!storage'),$which,bindval)
        }

        method EXISTS-KEY(TKey \key) {
            nqp::defined($!keys)
              ?? nqp::p6bool(nqp::existskey($!keys, nqp::unbox_s(key.WHICH)))
              !! False
        }

        method keys(Map:) {
            return ().list unless self.DEFINITE && nqp::defined($!keys);
            Seq.new(class :: does Iterator {
                has $!hash-iter;

                method new(\hash, $class) {
                    my \iter = nqp::create(self);
                    nqp::bindattr(iter, self, '$!hash-iter',
                        nqp::iterator(nqp::getattr(hash, $class, '$!keys')));
                    iter
                }

                method pull-one() {
                    $!hash-iter
                        ?? nqp::iterval(nqp::shift($!hash-iter))
                        !! IterationEnd
                }
            }.new(self, $?CLASS))
        }
        method kv(Map:) {
            return ().list unless self.DEFINITE && nqp::defined($!keys);

            my $storage := nqp::getattr(self, Map, '$!storage');
            Seq.new(class :: does Iterator {
                has $!hash-iter;
                has $!storage;
                has int $!on-value;
                has $!current-value;

                method new(\hash, $class, $storage) {
                    my \iter = nqp::create(self);
                    nqp::bindattr(iter, self, '$!hash-iter',
                        nqp::iterator(nqp::getattr(hash, $class, '$!keys')));
                    nqp::bindattr(iter, self, '$!storage', nqp::decont($storage));
                    iter
                }

                method pull-one() {
                    if $!on-value {
                        $!on-value = 0;
                        $!current-value
                    }
                    elsif $!hash-iter {
                        my \tmp = nqp::shift($!hash-iter);
                        $!on-value = 1;
                        $!current-value := nqp::atkey($!storage, nqp::iterkey_s(tmp));
                        nqp::iterval(tmp)
                    }
                    else {
                        IterationEnd
                    }
                }
            }.new(self, $?CLASS, nqp::getattr(self, Map, '$!storage')))
        }
        method pairs(Map:) {
            return ().list unless self.DEFINITE && nqp::defined($!keys);

            my $storage := nqp::getattr(self, Map, '$!storage');
            Seq.new(class :: does Iterator {
                has $!hash-iter;
                has $!storage;

                method new(\hash, $class, $storage) {
                    my \iter = nqp::create(self);
                    nqp::bindattr(iter, self, '$!hash-iter',
                        nqp::iterator(nqp::getattr(hash, $class, '$!keys')));
                    nqp::bindattr(iter, self, '$!storage', nqp::decont($storage));
                    iter
                }

                method pull-one() {
                    if $!hash-iter {
                        my \tmp = nqp::shift($!hash-iter);
                        Pair.new(nqp::iterval(tmp), nqp::atkey($!storage, nqp::iterkey_s(tmp)));
                    }
                    else {
                        IterationEnd
                    }
                }
            }.new(self, $?CLASS, nqp::getattr(self, Map, '$!storage')))
        }
        method antipairs(Map:) {
            self.map: { .value => .key }
        }
        method invert(Map:) {
            self.map: { .value »=>» .key }
        }
        multi method perl(::?CLASS:D \SELF:) {
            SELF.perlseen('Hash', {
                my $TKey-perl   := TKey.perl;
                my $TValue-perl := TValue.perl;
                $TKey-perl eq 'Any' && $TValue-perl eq 'Mu'
                  ?? ':{' ~ SELF.pairs.sort.map({.perl}).join(', ') ~ '}'
                  !! "(my $TValue-perl %\{$TKey-perl\} = {
                      self.pairs.sort.map({.perl}).join(', ')
                    })"
            })
        }
        multi method DELETE-KEY($key) {
            my Mu $val = self.AT-KEY($key);
            my $key-which = $key.WHICH;

            nqp::deletekey(
                nqp::getattr(self, $?CLASS, '$!keys'),
                nqp::unbox_s($key-which)
            );

            nqp::deletekey(
                nqp::getattr(self, Map, '$!storage'),
                nqp::unbox_s($key-which)
            );
            $val;
        }

        # gotta force capture keys to strings or binder fails
        method Capture(Map:D:) {
            my $cap := nqp::create(Capture);
            my $h := nqp::hash();
            for self.kv -> \k, \v {
                my str $skey = nqp::istype(k, Str) ?? k !! k.Str;
                nqp::bindkey($h, $skey, v);
            }
            nqp::bindattr($cap, Capture, '$!hash', $h);
            $cap
        }

    }
    method ^parameterize(Mu:U \hash, Mu:U \t, |c) {
        if c.elems == 0 {
            my $what := hash.^mixin(TypedHash[t]);
            # needs to be done in COMPOSE phaser when that works
            $what.^set_name("{hash.^name}[{t.^name}]");
            $what;
        }
        elsif c.elems == 1 {
            my $what := hash.^mixin(TypedHash[t, c[0].WHAT]);
            # needs to be done in COMPOSE phaser when that works
            $what.^set_name("{hash.^name}[{t.^name},{c[0].^name}]");
            $what;
        }
        else {
            die "Can only type-constrain Hash with [ValueType] or [ValueType,KeyType]";
        }
    }
}


sub circumfix:<{ }>(*@elems) { my % = @elems }
sub hash(*@a, *%h) { my % = flat @a, %h }

# XXX parse hangs with ordinary sub declaration
BEGIN my &circumfix:<:{ }> = sub (*@elems) { Hash.^parameterize(Mu,Any).new(@elems) }

# vim: ft=perl6 expandtab sw=4
