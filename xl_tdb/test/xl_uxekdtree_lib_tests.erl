%%  Copyright (c) 2012-2013
%%  StrikeAd LLC http://www.strikead.com
%%
%%  All rights reserved.
%%
%%  Redistribution and use in source and binary forms, with or without
%%  modification, are permitted provided that the following conditions are met:
%%
%%      Redistributions of source code must retain the above copyright
%%  notice, this list of conditions and the following disclaimer.
%%      Redistributions in binary form must reproduce the above copyright
%%  notice, this list of conditions and the following disclaimer in the
%%  documentation and/or other materials provided with the distribution.
%%      Neither the name of the StrikeAd LLC nor the names of its
%%  contributors may be used to endorse or promote products derived from
%%  this software without specific prior written permission.
%%
%%  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%%  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%%  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%%  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%%  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%%  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%%  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%%  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%%  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-module(xl_uxekdtree_lib_tests).
-author("volodymyr.kyrychenko@strikead.com").

-include_lib("xl_stdlib/include/xl_eunit.hrl").

expand_test() ->
    Points = [
        {1, [], ctx},
        {2, {x, []}, ctx},
        {[1, 2], [3, 4], ctx},
        {{x, x}, {x, y}, ctx},
        {{x, [1, 2]}, {x, 1}, ctx},
        {{x, [a, b, c]}, {x, [d, e]}, ctx}
    ],
    ExpectedPoints = [
        {1, undefined, ctx},
        {2, undefined, ctx},
        {1, 3, ctx},
        {2, 3, ctx},
        {1, 4, ctx},
        {2, 4, ctx},
        {{x, [x]}, {x, [y]}, ctx},
        {{x, [1, 2]}, {x, [1]}, ctx},
        {{x, [a, b, c]}, {x, [d, e]}, ctx}
    ],
    ?assertEquals(length(ExpectedPoints), xl_uxekdtree_lib:estimate_expansion(Points)),
    ?assertEquals(ExpectedPoints, xl_uxekdtree_lib:expand(Points)).


sorter_test() ->
    Sorter = xl_uxekdtree_lib:sorter(1),
    Points = [
        {1, c, c}, {undefined, b, ub1}, {3, a, a}, {2, undefined, uc}, {undefined, b, ub2},
        {3, a, a}, {2, c, c}, {1, b, b}, {3, a, a}, {2, c, c}
    ],
    Expected = [
        {undefined, b, ub1}, {undefined, b, ub2}, {1, c, c}, {1, b, b}, {2, undefined, uc},
        {2, c, c}, {2, c, c}, {3, a, a}, {3, a, a}, {3, a, a}
    ],
    ?assertEquals(Expected, lists:sort(Sorter, Points)).


planes_test() ->
    ?assertEqual([1, 2], xl_uxekdtree_lib:planes([{1, 2, undefined, x}])).