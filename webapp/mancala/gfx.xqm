module namespace gfx = 'http://xmlpraktikum.in.tum.de/modules/gfx';

declare namespace svg = "http://www.w3.org/2000/svg";
declare namespace xlink = "http://www.w3.org/1999/xlink";

import module  "http://basex.org/modules/random";
import module "http://www.w3.org/2005/xpath-functions/math";


declare function gfx:getScoreHole($tokenCount as xs:integer) as node(){
    let $scoreHole := gfx:prepareHole(db:open("mancaladb","score-scribble.svg"))
    return  fn:fold-left(gfx:getTokenInsertSequence($tokenCount), $scoreHole,
        function($scoreHole, $token){
            $scoreHole update insert node gfx:generateScoreHole($token, xs:integer(fn:count(.//svg:use[@xlink:href="#token"])), $tokenCount) into .//svg:g[@id="score"]
        }
    )
};


declare function gfx:getHole($tokenCount as xs:integer) as node(){
    let $hole := gfx:prepareHole(db:open("mancaladb","hole-scribble.svg")) 
    return  fn:fold-left(gfx:getTokenInsertSequence($tokenCount), $hole,
        function($hole, $token){
            $hole update insert node gfx:generatePlayHole($token, xs:integer(fn:count(.//svg:use[@xlink:href="#token"])), $tokenCount) into .//svg:g[@id="hole"]
        }
    )
};


declare function gfx:prepareHole($hole as node()) as node(){
    $hole update insert node db:open("mancaladb","token-scribble.svg")/svg:svg into ./svg:svg/svg:defs 
};


declare function gfx:getTokenInsertSequence($count as xs:integer)as  node()*{
    for $i in (1 to $count)
    return <use x="0" y="0" xlink:href="#token" />
};


declare function gfx:generateScoreHole($path as node(),$a as xs:integer, $seed as xs:integer) as node() {
    (: 48 because 12 holes with max. 4 token. So if every token on the board would be in one hole, this sequence would be sufficient 
    the calculation combined with the addition in the actual update statement is used to find valid coordinates in range of the
    bounding box of the holes. The ranges for the seeded-integer function are precalculated based on our SVGs.
    :)
    let $randXCoordinates := random:seeded-integer($seed, 48, 600) 
    let $randYCoordinates := random:seeded-integer($seed, 48, 1370)

    return $path 
    update {replace value of node ./@x with $randXCoordinates[$a+1] + 50} 
    update {replace value of node ./@y with $randYCoordinates[$a+1] - 300}
};


declare function gfx:generatePlayHole($path as node(),$a as xs:integer, $seed as xs:integer) as node() {
    (: Same procedure as in gfx:generateScoreHole :)
    let $randXCoordinates := random:seeded-integer($seed + 1, 48,370) 
    let $randYCoordinates := random:seeded-integer($seed + 1, 48,445)

    return $path 
    update {replace value of node ./@x with $randXCoordinates[$a+1] + 130} 
    update {replace value of node ./@y with $randYCoordinates[$a+1] + 130}
};