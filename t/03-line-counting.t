use Test::More;
use C::Blocks;

#line 1 "test.pl"
cblock {}
is(__LINE__, 2, "Completely empty block reports correct lines");

#line 1 "test.pl"
cblock {
}
is(__LINE__, 3, "Empty with one newline reports correct lines");

#line 1 "test.pl"
cblock {

}
is(__LINE__, 4, "Empty with two newlines reports correct lines");

#line 1 "test.pl"
cblock {


}
is(__LINE__, 5, "Empty with three newlines reports correct lines");

#line 1 "test.pl"
cblock { ${ '' } }
is(__LINE__, 2, "Empty block with empty interpolation block reports correct lines");

#line 1 "test.pl"
cblock { ${ '' }
}
is(__LINE__, 3, "Empty block with empty interpolation block followed by single newline reports correct lines");

#line 1 "test.pl"
cblock {
${ '' } }
is(__LINE__, 3, "Empty block with single newline followed by empty interpolation block reports correct lines");

#line 1 "test.pl"
cblock {
${ '' }
}
is(__LINE__, 4, "Empty block with empty interpolation block surrouned by newlines reports correct lines");

done_testing;
