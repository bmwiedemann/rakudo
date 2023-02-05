class RakuAST::Pragma
  is RakuAST::Statement
  is RakuAST::BeginTime
  is RakuAST::ProducesNil
{
    has Str $.name;
    has RakuAST::Expression $.argument;
    has int $.off;

    method new(Str :$name!, RakuAST::Expression :$argument, :$off) {
        my $obj := nqp::create(self);
        nqp::bindattr(  $obj, RakuAST::Pragma, '$!name', $name // "");
        nqp::bindattr(  $obj, RakuAST::Pragma, '$!argument', $argument);
        nqp::bindattr_i($obj, RakuAST::Pragma, '$!off', $off ?? 1 !! 0);
        $obj
    }

    method PRODUCE-IMPLICIT-LOOKUPS() {
        self.IMPL-WRAP-LIST([
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('Nil')),
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('Pair')),
            RakuAST::Type::Setting.new(RakuAST::Name.from-identifier('Bool')),
        ])
    }

    method IS-NYI(Str $name) {
        my constant NYI-PRAGMAS := nqp::hash(
          'internals',  1,
          'invocant',   1,
          'parameters', 1,
        );

        nqp::existskey(NYI-PRAGMAS, $name)
    }

    method KNOWN-PRAGMAS() {
        # 0 means specific handling required, 1 means just (un)set pragma
        # by that name
        my constant KNOWN-PRAGMAS := nqp::hash(
          'attributes',         0,
          'dynamic-scope',      0,
          'fatal',              0,
          'internals',          1,
          'invocant',           0,
          'isms',               0,
          'MONKEY',             0,
#          'MONKEY-BARS',        1,
#          'MONKEY-BRAINS',      1,
#          'MONKEY-BUSINESS',    1,
          'MONKEY-GUTS',        1,
          'MONKEY-SEE-NO-EVAL', 1,
#          'MONKEY-SHINE',       1,
#          'MONKEY-TRAP',        1,
          'MONKEY-TYPING',      1,
#          'MONKEY-WRENCH',      1,
          'nqp',                1,
          'parameters',         0,
          'precompilation',     0,
          'soft',               0,
          'strict',             1,
          'trace',              1,
          'variables',          0,
          'worries',            1,
        );
    }

    method IS-PRAGMA(Str $name) {
        nqp::existskey(self.KNOWN-PRAGMAS, $name)
    }

    method KNOWN-ISMS() {
        my constant ISMS := nqp::hash(
          'Perl5', 'p5isms',
          'C++',   'c++isms',
        )
    }

    method IS-ISM(Str $name) {
        nqp::existskey(self.KNOWN-ISMS, $name)
    }

    # needed by BeginTime
    method categoricals() { () }

    method PERFORM-BEGIN(
      RakuAST::Resolver $resolver,
      RakuAST::IMPL::QASTContext $context
    ) {
        my $name    := $!name;
        my int $on  := nqp::not_i($!off);
        my $arglist := $!argument
          ?? self.IMPL-BEGIN-TIME-EVALUATE(
               $!argument, $resolver, $context
             ).List.FLATTENABLE_LIST
          !! Nil;

        if self.IS-NYI($name) {
            $resolver.build-exception(
              'X::NYI',
              :feature(($on ?? 'use' !! 'no') ~ " $name"),
            ).throw;
        }
        elsif self.KNOWN-PRAGMAS{$name} {
            nqp::islist($arglist)
              ?? $resolver.build-exception('X::Pragma::NoArgs', :$name).throw
              !! $*LANG.set_pragma($name, $on)
        }
        elsif $name eq 'MONKEY' {
            $*LANG.set_pragma($_.key, $on)
              if nqp::eqat($_.key,'MONKEY',0) for self.KNOWN-PRAGMAS;
        }
        elsif $name eq 'precompilation' {
            if $!off && $*CU.precompilation-mode {
                nqp::ifnull(
                  nqp::atkey(nqp::getenvhash, 'RAKUDO_PRECOMP_WITH'), 0
                ) ?? nqp::exit(0)
                  !! $resolver.build-exception(
                       'X::Pragma::CannotPrecomp', :what<no>, :$name
                     ).throw;
            }
        }
        elsif $name eq 'fatal' {
            nqp::die("use fatal NYI") if $on;
        }
        elsif $name eq 'isms' {
            if nqp::islist($arglist) {
                for $arglist -> $ism {
                    (my $pragma := self.KNOWN-ISMS{$ism})
                      ?? $*LANG.set_pragma($pragma, $on)
                      !! $resolver.build-exception(
                           "X::Ism::Unknown", :name($ism)
                         ).throw;
                }
            }
            else {
                $*LANG.set_pragma($_.value, $on) for self.KNOWN-ISMS;
            }
        }
        elsif $name eq 'soft' {
            nqp::islist($arglist)
              ?? $resolver.build-exception(
                   'X::NYI',
                   :feature("Arguments to '{$on ?? 'use' !! 'no' } soft'"),
                 ).throw
              !! $*LANG.set_pragma($name, $on);
        }
        elsif $name eq 'attributes'
           || $name eq 'invocant'
           || $name eq 'parameters'
           || $name eq 'variables' {

            $resolver.build-exception(
              'X::Pragma::CannotWhat', :what<no>, :$name
            ).throw unless $on;

            $resolver.build-exception(
              'X::Pragma::MustOneOf', :$name, :alternatives(':D, :U or :_')
            ).throw unless $arglist;

            my @lookups := self.IMPL-UNWRAP-LIST(self.get-implicit-lookups);
            my $Pair := @lookups[1];
            my $Bool := @lookups[2];

            my $type;
            for $arglist -> $arg {
                if $type {
                    $resolver.build-exception(
                      'X::Pragma::OnlyOne', :$name
                    ).throw;
                }
                elsif nqp::istype($arg,$Pair) {
                    my $value := $arg.value;
                    if nqp::istype($value,$Bool) && $value {
                        $type := $arg.key;
                        if $type eq 'D' || $type eq 'U' {
                            $*LANG.set_pragma($name, $type);
                            next;
                        }
                        elsif $type eq '_' {
                            # XXX shouldn't know this
                            nqp::deletekey($*LANG.slangs,$name);
                            next;
                        }
                    }
                    $resolver.build-exception(
                      'X::InvalidTypeSmiley', :name($arg.key)
                    ).throw;
                }
                $resolver.build-exception(
                  'X::Pragma::UnknownArg', :$name, :$arg
                ).throw;
            }
        }
        else {
            $resolver.build-exception("X::Pragma::Unknown",:$name).throw;
        }
    }
}
