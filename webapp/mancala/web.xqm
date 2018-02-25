module namespace web = 'http://xmlpraktikum.in.tum.de/modules/web';

import module  "http://basex.org/modules/random";
import module 'http://xmlpraktikum.in.tum.de/modules/game' at './game.xqm';
import module 'http://xmlpraktikum.in.tum.de/modules/gfx'at './gfx.xqm';

declare namespace game = "http://xmlpraktikum.in.tum.de/modules/game";
declare namespace gfx = "http://xmlpraktikum.in.tum.de/modules/gfx";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace functx = "http://www.functx.com";
declare namespace webutil = "http://basex.org/modules/web";

declare
%rest:path("/")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function web:start()
as element(Q{http://www.w3.org/1999/xhtml}html) {
  db:open("mancaladb","index.html")/*
};


declare
%rest:path("/manual")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function web:manual()
as element(Q{http://www.w3.org/1999/xhtml}html) {
  db:open("mancaladb","manual.html")/*
};

declare
%rest:path("/zug/{$id}")
%output:method("xhtml")
%rest:query-param("id", "{$gameID}","error")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
%updating
function web:zug($id as xs:string, $gameID as xs:string) {
  if(web:isNumber($id) and web:isValidMove(xs:integer($id), $gameID)) then(
    let $state := game:GetGameStateFromSession($gameID)
    let $state := game:MakeMove($state,xs:integer($id))
    let $scores := web:generateBoard($state)
    return (
      db:replace('mancaladb', fn:concat('GameState-',$state//sessionId/text(),'.xml'), $state),
      if ($state//gameOver = "false")
      then (
        db:output($scores)
      ) else (
        db:output(webutil:redirect(fn:concat("/gameover?id=", $gameID)))
      )
    )
  ) else (
          db:output(web:error("Error making that move. Please use the back button in your browser"))
  )
};


declare function web:isValidMove($id as xs:integer, $gameID as xs:string) as xs:boolean{
  web:isValidgameID($gameID)
    and $id < 14 and $id > 0 and $id != 7
};

declare function web:isValidgameID($gameID as xs:string) as xs:boolean {
  fn:compare($gameID, "error") != 0
    and fn:compare(game:GetGameStateFromSession($gameID)//statusCode/text(),"-1") != 0
};

declare
function web:error($error as xs:string) as node(){
  db:open("mancaladb", "error.html") update insert node xs:string($error) into .//html:p[@id="error"]
};


declare
%rest:path("/scoreboard")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
%updating
function web:scoreboard() {
  let $table := web:createTableRowOfScoreBoard(db:open("mancaladb","scoreboard.html"))
  return db:output($table)
};

declare
%rest:path("/newgame")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
%updating
function web:newgame() {
  let $state := game:NewGame()
  let $html := web:generateBoard($state)
  let $gameID := $state//sessionId/text()
  return (
    db:output(webutil:response-header(
      map{ "media-type" : "text/html"},
      map{ "Cache-Control" : "no-cache, no-store, must-revalidate",
           "Expires" : "0",
           "Set-Cookie" : fn:concat("mancala-gameID=", $gameID, "; Path=/loadgame; Max-Age=2678411") })),
    db:output($html),
    db:add('mancaladb', $state, fn:concat('GameState-',$gameID,'.xml'))
  )
};

declare
%rest:path("/loadgame")
%rest:cookie-param("mancala-gameID", "{$gameID}", "error")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
%updating
function web:loadgame($gameID as xs:string) {
  if (web:isValidgameID($gameID))
  then (
    let $state := (
      copy $x := game:GetGameStateFromSession($gameID)
      modify (
        insert node "Loaded existing game. " as first into $x//statusMessage
      )
      return $x
    )
    return db:output(web:generateBoard($state))
  ) else (
    web:newgame()
  )
};

declare %private function web:generateBoard($state as node()) as node(){
  let $html := web:setHoleCount($state, db:open("mancaladb","game.html"))
  let $html := web:setLinks($state, $html)
  let $html := web:setClasses($state, $html)
  let $html := web:setInfoBar($state, $html)
  return web:assembleHoles($state, $html)
};


declare %private function web:setInfoBar($state as node(), $html as node()) as node(){
   $html update insert node $state//statusMessage/text() as first into .//*[@id="infobar"]
};

declare function web:isNumber( $value as xs:anyAtomicType?)  as xs:boolean {
   string(number($value)) != 'NaN'
};

declare %private function web:assembleHoles($state as node(), $html as node()){
 copy $htmlCopy := $html
    modify (
      for $tokenState in $state//Token[@id!=0 and @id!=7]
        return insert node gfx:getHole(xs:integer($tokenState/text())) into $htmlCopy//html:div[@id=$tokenState/@id]/html:a,
       for $tokenState in $state//Token[@id=0 or @id=7]
        return insert node gfx:getScoreHole(xs:integer($tokenState/text())) into $htmlCopy//html:div[@id=$tokenState/@id]
  )
  return $htmlCopy
};

declare %private function web:setHoleCount($state as node(), $html as node()) as node(){
   copy $htmlCopy := $html
    modify (
      for $tokenCount in $state//Token
        return insert node $tokenCount/text() into $htmlCopy//html:div[@id=$tokenCount/@id]
  )
  return $htmlCopy
};

declare %private function web:setLinks($state as node(), $html as node()) as node(){
      copy $htmlCopy := $html
      modify (
          if($state//currentPlayer = "Player 1") then (
        for $link in $htmlCopy//html:div[contains(./@class,"hole") and @id > 0 and @id < 7 and text() != "0"]
          return  replace value of node $link//html:a/@href with "../zug/"|| $link/@id || "?id=" || $state//sessionId/text(),
        for $noLink in $htmlCopy//html:div[contains(./@class,"hole") and @id < 14 and @id > 7 or text() = "0"]
          return delete node $noLink//html:a/@href
          )else(
           for $link in $htmlCopy//html:div[contains(./@class,"hole") and @id < 14 and @id > 7 and text() != "0"]
          return  replace value of node $link//html:a/@href with "../zug/"|| $link/@id || "?id=" || $state//sessionId/text(),
        for $noLink in $htmlCopy//html:div[contains(./@class,"hole") and (@id > 0 and @id < 7) or text() = "0" ]
                    return delete node $noLink//html:a/@href
        )
          )
      return $htmlCopy

};

declare %private function web:setClasses($state as node(), $html as node()) as node(){
      copy $htmlCopy := $html
      modify (
          if($state//currentPlayer = "Player 1") then (
            for $link in $htmlCopy//html:div[contains(./@class,"hole") and @id > 0 and @id < 7 and text() != "0" ]
              return replace value of node $link/@class with fn:replace($link/@class, "noactive", "active")
          ) else(
            for $link in $htmlCopy//html:div[contains(./@class,"hole") and @id < 14 and @id > 7 and text() != "0" ]
              return replace value of node $link/@class with fn:replace($link/@class, "noactive", "active")
          )
        )
      return $htmlCopy
};


declare %private function web:createTableRowOfScoreBoard($html as node()) as node()* {
  copy $htmlCopy := $html
  modify (
    for $c in db:open("mancaladb")/GameState
    where xs:string($c//gameOver) = 'true'
    return insert node
    <tr>
    <td> {$c//sessionId} </td>
    <td> {$c//players/player[@id="1"]/text()} </td>
    <td> {$c//players/player[@id="2"]/text()} </td>
    <td> {$c//Token[@id="0"]|| " - " || $c//Token[@id="7"]}</td>
    </tr>
    as last into $htmlCopy//html:table[@id="scoreboard"]
  )
  return $htmlCopy
};

declare
%rest:path("/gameover")
%rest:query-param("id", "{$gameID}", "error")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
function web:gameover($gameID as xs:string) {
  if (web:isValidgameID($gameID))
  then (
    let $state := game:GetGameStateFromSession($gameID)
    let $winner := $state//currentPlayer
    return (
    copy $x := db:open("mancaladb", "gameover.html")
    modify (
      replace value of node $x//html:form[@id="playernames"]/@action with fn:concat($x//html:form[@id="playernames"]/@action, "/", $gameID),
      insert node $winner/text() as last into $x//html:b[@id="winner"],
      insert node
        <tr>
          <td>{$state//sessionId}</td>
          <td></td>
          <td></td>
          <td>{$state//Token[@id="7"]|| " - " || $state//Token[@id="0"]}</td>
        </tr>
      as last into $x//html:table[@id="scoreboard"]
    )

    return $x
    )
  ) else (
    web:error("It seems you are not coming from a finished game.")
  )
};

declare
%rest:path("/savescore/{$gameID}")
%rest:query-param("player1", "{$player1}", "Player 1")
%rest:query-param("player2", "{$player2}", "Player 2")
%output:method("xhtml")
%output:omit-xml-declaration("no")
%output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
%output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
%updating
function web:savescore($gameID as xs:string, $player1 as xs:string, $player2 as xs:string) {
  if (web:isValidgameID($gameID))
  then (
    let $updateResult := game:UpdatePlayerNames($gameID, $player1, $player2)
    return (
      if ($updateResult = "Error")
      then (
        db:output(webutil:redirect("/"))
      )
      else (
        db:replace('mancaladb', fn:concat('GameState-',$updateResult//sessionId/text(),'.xml'), $updateResult),
        db:output(webutil:redirect("/scoreboard"))
      )
    )
  ) else (
    db:output(web:error("It seems you are not coming from a finished game."))
  )
};
