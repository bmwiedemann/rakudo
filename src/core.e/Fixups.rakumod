# This file contains fixups to existing core classes by means of augmentation
# for language level 6.e.

augment class Any {

    # introducing snip
    proto method snip(|) {*}
    multi method snip(Any:D: \condition) {
        Seq.new: Rakudo::Iterator.Snip(condition.iterator, self.iterator)
    }
    multi method snip(Any:D: @conditions) {
        Seq.new: Rakudo::Iterator.Snip(@conditions.iterator, self.iterator)
    }
    multi method snip(Any:D: *@conditions) {
        Seq.new: Rakudo::Iterator.Snip(@conditions.iterator, self.iterator)
    }

    multi method skip(Iterable:D $skips) {
        Seq.new: Rakudo::Iterator.Skipper: self.iterator, $skips.iterator
    }
    multi method skip(*@skips) {
        self.skip(@skips)
    }

    # introducing snitch
    proto method snitch(|) {*}
    multi method snitch(Seq:D \SNITCHEE: &snitcher = &note) is raw {
        snitcher SNITCHEE.cache;
        SNITCHEE
    }
    multi method snitch(\SNITCHEE: &snitcher = &note) is raw {
        snitcher SNITCHEE;
        SNITCHEE
    }
}

#-------------------------------------------------------------------------------
augment class Bag {

    # add support for Format formats
    multi method fmt(Bag:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class BagHash {

    # add support for Format formats
    multi method fmt(BagHash:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class Complex {

    # handle sign correctly
    method sign(Complex:D: --> Complex:D) {
        $_ == 0 ?? 0i !! self / $_ given self.abs;
    }
}

#-------------------------------------------------------------------------------
augment class Int {

    # handle negative sqrts being Complex
    multi method sqrt(Int:D:) is default {
        nqp::islt_I(self,0)
          ?? Complex.new(
               0,
               nqp::p6box_n(nqp::sqrt_n(nqp::abs_n(nqp::tonum_I(self))))
             )
          !! nqp::p6box_n(nqp::sqrt_n(nqp::tonum_I(self)))
    }

    # allow 42.roll to be short for (^42).roll
    proto method roll(|) {*}
    multi method roll() { nqp::rand_I(self,Int) }
    multi method roll($count) { (^self).roll($count) }

    # allow 42.pick to be short for (^42).pick
    proto method pick(|) {*}
    multi method pick() { nqp::rand_I(self,Int) }
    multi method pick($count) { (^self).pick($count) }
}

#-------------------------------------------------------------------------------
augment class List {

    # add support for Format formats
    multi method fmt(List:D: Format:D $format, $separator = ' ' --> Str:D) {
        self.is-lazy
          ?? self.fail-iterator-cannot-be-lazy('.fmt',"")
          !! $format.handle-iterator: self.iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class Map {

    # add support for Format formats
    multi method fmt(Map:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class Mix {

    # add support for Format formats
    multi method fmt(Mix:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class MixHash {

    # add support for Format formats
    multi method fmt(MixHash:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class Num {

    # handle negative logs being Complex
    multi method log(Num:D:) is default {
        nqp::islt_n(self,0e0)
          ?? Complex.new(
               nqp::p6box_n(nqp::log_n(nqp::abs_n(nqp::unbox_n(self)))),
               pi
             )
          !! nqp::p6box_n(nqp::log_n(nqp::unbox_n(self)));
    }

    # handle negative sqrts being Complex
    multi method sqrt(Num:D:) is default {
        nqp::islt_n(self,0e0)
          ?? Complex.new(
               0,
               nqp::p6box_n(nqp::sqrt_n(nqp::abs_n(nqp::unbox_n(self))))
             )
          !! nqp::p6box_n(nqp::sqrt_n(nqp::unbox_n(self)));
    }
}

#-------------------------------------------------------------------------------
augment class Pair {

    # add support for Format formats
    multi method fmt(Pair:D: Format:D $format --> Str:D) {
        $format($!key, $!value)
    }
}

#-------------------------------------------------------------------------------
augment class Range {

    # handle Range.Bool correctly
    multi method Bool(Range:D: --> Bool:D) {
        nqp::hllbool($!is-int
          ?? ($!max - $!excludes-max - $!min - $!excludes-min) > -1
          !! nqp::not_i(nqp::eqaddr(self.iterator.pull-one,IterationEnd))
        )
    }
}

#-------------------------------------------------------------------------------
augment class Seq {

    # add support for Format formats
    multi method fmt(Seq:D: Format:D $format, $separator = ' ' --> Str:D) {
        self.is-lazy
          ?? self.fail-iterator-cannot-be-lazy('.fmt',"")
          !! $format.handle-iterator: self.iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class Set {

    # Add support for Format formats.   Note that the invocant is marked
    # as Setty rather than Set, because this will serve as the handler
    # for the SetHash class.  Sadly, it is not possible to augment roles,
    # otherwise the Setty role itself would have been augmented.
    multi method fmt(Set:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class SetHash {

    # add support for Format formats
    multi method fmt(SetHash:D: Format:D $format, $separator = "\n" --> Str:D) {
        $format.handle-iterator:
          ($format.count == 1 ?? self.keys !! self.kv).iterator, $separator
    }
}

#-------------------------------------------------------------------------------
augment class Str {

    # introduce rotor-like capabilities to comb
    multi method comb(Str:D: Pair:D $what, $limit = *, :$partial) {
        my int $size = $what.key;
        my int $step = $size + $what.value;
        $step = 1 if $step < 1;
        $size <= 1 && (nqp::istype($limit,Whatever) || $limit == Inf)
          ?? self.comb
          !! Seq.new:
               Rakudo::Iterator.NGrams: self, $size, $limit, $step, $partial

    }
}

#-------------------------------------------------------------------------------
augment class Supply {

    # introducing snip
    proto method snip($, |) {*}
    multi method snip(Supply:D: $test) {
        self.snip( ($test,) )
    }

    multi method snip(Supply:D: @tests) {
        my @left    = @tests;
        my $test   := @left ?? @left.shift !! Nil;
        my $buffer := nqp::create(IterationBuffer);
        supply {
            whenever self -> \val {
                if nqp::eqaddr($test,Nil) {
                    nqp::push($buffer,val);
                }
                elsif $test.ACCEPTS(val) {
                    emit $buffer.List;
                    nqp::push(($buffer := nqp::create(IterationBuffer)),val);
                    $test := @left ?? @left.shift !! Nil;
                }
                else {
                    nqp::push($buffer,val);
                }
                LAST {
                    emit $buffer.List;
                }
            }
        }
    }

    multi method snip(Supply:D: *@tests) {
        self.snip(@tests)
    }
}

# vim: expandtab shiftwidth=4
