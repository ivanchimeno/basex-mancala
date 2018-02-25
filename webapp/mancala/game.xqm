module namespace game = 'http://xmlpraktikum.in.tum.de/modules/game';
import module  namespace random = "http://basex.org/modules/random";
import module namespace hash = "http://basex.org/modules/hash";

(:
  ######################## Start Public Functions ########################
:)

(:  Starts a new game and returns the initial GameState. :)
declare function game:NewGame() as node()  {
  let $sessionId := xs:string(game:GenerateSessionId())
  let $gameState := game:CreateNewGameState($sessionId)
  return $gameState
};

(:  Retrieves the GameState XML node from a given sessionId.  :)
declare function game:GetGameStateFromSession($sessionId as xs:string) as node() {
  let $filename := fn:concat('GameState-', $sessionId, '.xml')
  let $exists := db:exists('mancaladb', $filename)
  return (
    if ($exists) 
    then (
      db:open('mancaladb', $filename)//GameState
    )
    else (
      let $errorMessage := fn:concat('Cannot get game state because ', $filename, 'does not exist.')
      return game:ReturnGameStateError('-1',$errorMessage)
    )
  ) 
};

(: Updates the name of the players :)
declare function game:UpdatePlayerNames($sessionId as xs:string, $player1 as xs:string, $player2 as xs:string) {
  let $filename := fn:concat('GameState-', $sessionId, '.xml')
  let $exists := db:exists('mancaladb', $filename)
  return (
    if ($exists) 
    then ( 
      copy $x := db:open('mancaladb', $filename)
      modify (
        replace value of node $x//player[@id="1"] with $player1,
        replace value of node $x//player[@id="2"] with $player2
      )
      return $x     
    )
    else (
      "Error"
    )
  )
};

(: Makes a move and returns the updated GameState :)
declare function game:MakeMove($GameState as node(), $holeID as xs:integer) as node() {
  let $currentPlayer := xs:string($GameState//currentPlayer)
  let $opponentPlayer := if( $currentPlayer = 'Player 1') then 'Player 2' else 'Player 1'
  let $beanCount := xs:integer($GameState//Token[@id=$holeID])
  let $gameState1 := (
    copy $c := $GameState
    modify (
      replace value of node $c//Token[@id=$holeID] with '0'
    )
    return $c
  )

  (: Make the move :)
  let $modifiedTokensAfterIter := game:PlaceBeansInEachToken($gameState1, $currentPlayer, $beanCount)
  let $updatedGameStateAfterMove := game:PlaceBeansInPartToken($modifiedTokensAfterIter, $currentPlayer, $holeID, $beanCount mod 12)

  let $targetTokenId := (
    let $result := $holeID + $beanCount
    return if ($result >= 14) then 14 - $result else $result
  )

   return (
     (: Return the old GameState if player move is invalid :)
     if(game:IsPlayerMoveValid($GameState, $holeID) = 0) then $GameState else (
       (: Return game over state if the game is actually over :)
       if(game:CheckGameOver($updatedGameStateAfterMove) = 1) then  game:MakeGameOver($updatedGameStateAfterMove)
       else (
         copy $c := $updatedGameStateAfterMove
         modify (
           (: First exception rule, we modify nothing because: 
              If, when dropping stones in holes, you drop a stone into your own mancala, 
              and that is the last stone in your hand, then you get to go again. :)
            let $targetMancala := if ($GameState//currentPlayer = 'Player 1') then 7 else 0
            return (
              if(game:IsLastBeanInHole($GameState, $holeID, $targetMancala) = 1) then (
                replace value of node $c//statusMessage with fn:string-join(("It's your move again, ", $currentPlayer),"")
              ) 
              else (
                if (game:CanTakeBeansFromAbove($updatedGameStateAfterMove,$targetTokenId) = 1)
                then (
                  (:Take all beans inside the opposite token and insert into player's mancala :)
                  let $oppositeToken := 14 - $targetTokenId
                  let $beanCount := xs:integer($updatedGameStateAfterMove//Token[@id=$oppositeToken])
                  let $beanNoun := if ($beanCount = 1) then "bean" else "beans" 
                  let $targetMancalaBeans := xs:integer($updatedGameStateAfterMove//Token[@id=$targetMancala])
                  return (
                    replace value of node $c//Token[@id=$oppositeToken] with '0',
                    replace value of node $c//Token[@id=$targetMancala] with ($targetMancalaBeans + $beanCount),
                    replace value of node $c//currentPlayer with $opponentPlayer,
                    replace value of node $c//statusMessage with fn:string-join(($currentPlayer, " stole ", $beanCount, " ", $beanNoun, " from ", $opponentPlayer, "!", "&#10;",$opponentPlayer, " it's your turn!"),"")
                  )
                )
                (: Both exception rules did not occur, so switch players :)
                else(
                  replace value of node $c//currentPlayer with $opponentPlayer,
                  replace value of node $c//statusMessage with fn:string-join(("Your turn ",$opponentPlayer, "!"),"")
                )
              )
            )
         )   
         return (
           if(game:CheckGameOver($c) = 1) then  game:MakeGameOver($c) else $c
         )
       ) 
     )
   )
};

(:
  ######################## End Public Functions ########################
:)


declare %private function game:IsLastBeanInHole ($GameState as node(), $startTokenId as xs:integer, $endTokenId as xs:integer) as xs:integer {  
  (: Get the bean count inside the specified token and remove redundant beans :)
  let $beanCount := xs:integer($GameState//Token[@id=$startTokenId])
  let $beanCount := $beanCount mod 13

  (: We calculate targetTokenId by adding the beans to the startTokenId.
     If we reached the token limit we just subtract by 14 :)
  let $targetTokenId := (
    let $result := $startTokenId + $beanCount
    return if ($result >= 14) then 14 - $result else $result
  )
  
  return if ($targetTokenId = $endTokenId) then 1 else 0
};

(:  Should be executed after a player makes a move. Returns true if the player can take all
    of the beans from the opposite holes. 
    The rule is: 
      1) If the last stone is inside a hole which was previously empty and
      2) the hole is on the currentPlayer's side. 
:)
declare %private function game:CanTakeBeansFromAbove($GameState as node(), $holeID as xs:integer) as xs:integer {
  let $currentPlayer := xs:string($GameState//currentPlayer)
  let $beanCount := xs:integer($GameState//Token[@id=$holeID])
  
  (: Returns true if the token is within player range :)
  let $isPlayerRange := (
      if (($currentPlayer = 'Player 1' and $holeID >= 1 and $holeID < 7) 
      or ($currentPlayer = 'Player 2' and $holeID >= 8 and $holeID < 14)) then 1 
      else 0
  )
  
  return (if ($beanCount = 1 and $isPlayerRange = 1) then 1 else 0)
};

(: Move is invalid IF:
   [1] Player clicks on mancala
   [2] Player clicks on other player hole or mancala
   [3] The game is not over :)
declare %private function game:IsPlayerMoveValid($GameState as node(), $holeID as xs:integer) as xs:integer  {
  let $curPlayer := xs:string($GameState//currentPlayer)
  let $beanCount := xs:integer($GameState//Token[@id=$holeID])
  let $gameOver := xs:string($GameState//gameOver)
  return (
    (: Check validity for player 1 :)
    if ($curPlayer = 'Player 1') 
    then (
      (: Available holes for player 1 are between 1 and 6 :)
      if ($holeID >= 1 and $holeID <= 6 and $beanCount > 0 and $gameOver = 'false') 
      then 1 
      else 0
    )
    (: Check validity for player 2  :)
    else (
      (: Available holes for player 2 are between 8 and 13 :)
        if ($holeID >= 8 and $holeID <= 13 and $beanCount > 0 and $gameOver = 'false') 
        then 1
        else 0
    )
  )    
};

(: Updates the value of the token by value:)
declare %private function game:UpdateToken($token as node(), $value as xs:integer) as node() {
  copy $c := $token
  modify (
    replace value of node $c with $value
  )
  return $c
};

declare %private function game:UpdateTokensInGameState($GameState as node(), $Tokens as node()*) as node() {
  copy $c := $GameState
  modify (
    for $token in $Tokens
    return replace value of node $c//Token[@id=$token/@id] with $token/text()
  )
  return $c
};

(: Places x beans into every token (and the mancala of the current player).
   This function will only insert beans if beanCount >= maxTokens=13
   which means that a full board iteration is required.
   
   For example: BeanCount=40 -> 3 Beans will be inserted into each token :)
declare %private function game:PlaceBeansInEachToken($GameState as node(), $currentPlayer as xs:string, $beanCount as xs:integer) as node()   {
  (: Not 14 because we don't insert a bean into the opponents mancala. :)
  let $totalHoles := 13
  
  (: We save the tokenId where we do not insert a bean into. :)
  let $opponentTokenId := if ($currentPlayer = 'Player 1') then 0 else 7
  
  (: Here we calculate how much beans we have to insert inside each hole.
     This happens when the player has more beans than the amount of available
     holes.
     We just calculate the floor of beanCount/totalholes :)
  let $iterCount := (
    if($beanCount >= $totalHoles) 
    then xs:integer(fn:floor($beanCount div $totalHoles)) 
    else 0
  )
 
  (: Here we construct the list of nodes we will be returning.
     If the iteration count is 0, then we return the Token node
     list of the original GameState.
     Otherwise we loop and update the GameState and return that.:)
  let $result := (
    if($iterCount = 0 ) then $GameState//Token
    else(
      for $token in $GameState//Token
        let $tokenId := xs:integer($token/@id)
        where $tokenId != $opponentTokenId
      return game:UpdateToken($token, xs:integer($token) + $iterCount) 
    )
  )
  
  return game:UpdateTokensInGameState($GameState,$result)
};

declare %private function game:PlaceBeansInPartToken($GameState as node(), $currentPlayer as xs:string, $startTokenId as xs:integer, $beanCount as xs:integer) as node() {
  (: The amount of tokens and mancalas :)
  let $maxHoles := if ($currentPlayer = 'Player 1') then 13 else 14
  
  (: Wrapping occurs when loop goes from tokenId=13 -> tokenId=0 :)
  let $shouldWrap := if ( $beanCount >= ($maxHoles - $startTokenId)) then 1 else 0
  
  (: When wrapping occurs, we fill up tokens until tokenId=13.
     The calculated rest is the amount of beans to place from 
     tokenId=0/1 :)
  let $rest := if ($shouldWrap) then $beanCount - ($maxHoles - $startTokenId) else 0
   
  let $result := (
    for $token in $GameState//Token
      let $tokenId := xs:integer($token/@id)
      
      (: Define the condition when no wrapping is needed. :)
      let $condiNoWrap := $tokenId > $startTokenId and $tokenId <= ($startTokenId + $beanCount)
    
      let $condiWrap := (
        if ($currentPlayer = 'Player 1') then (
          (: Here we do 'wrapping' for player 1 because the number of beans to insert 
             is bigger then player 1's holes, but small enough to not do a full iteration.
             Returns all tokens from player 1's holes + some holes of player 2 :)
          ($tokenId > $startTokenId and $tokenId <= $maxHoles) or ($tokenId >= 1 and $tokenId <= $rest)
        )
        else (
          ($tokenId > $startTokenId and $tokenId <= ($maxHoles - 1)) or ($tokenId >= 0 and $tokenId <= $rest)
        )
      )
    
    where if($shouldWrap = 0) then $condiNoWrap else $condiWrap
    order by xs:integer($tokenId)
    return game:UpdateToken($token, xs:integer($token) + 1)
  )
  
  return game:UpdateTokensInGameState($GameState,$result)
};

(: Checks each hole of the current player and returns true if no beans are inside
   any of them :)
declare %private function game:CheckGameOver($GameState as node()) as xs:integer  {
  (: We sum up all the beans inside the current player's holes :)
  let $beanSum1 := game:BeanCountInTokens($GameState, 'Player 1')
  let $beanSum2 := game:BeanCountInTokens($GameState, 'Player 2')
  
  (: The game is over when the bean count is 0. :)
  return if ($beanSum1 = 0 or $beanSum2 = 0) then 1 else 0
};

(: Returns the GameState when a game is over.
   The gameOver element is set to true and all leftover
   beans are inserted into opponent's mancala. :)
declare %private function game:MakeGameOver($GameState as node()) as node()  {
  (:  Retrieve the current player, use it to get the opponent and his
      mancala. :)
  let $currentPlayer := xs:string($GameState//currentPlayer)
  let $opponent := if ($currentPlayer = 'Player 1') then 'Player 2' else 'Player 1'
  let $opponentMancala := if ($opponent = 'Player 1') then 7 else 0
  let $playerMancala := if($currentPlayer = 'Player 1') then 7 else 0
  
  (: Retrieve beans inside opponent's mancala and add it with the sum of
     the leftover beans that are on the opponent's side. :)
  let $opponentScore := xs:integer($GameState//Token[@id=$opponentMancala])
  let $opponentScore := game:BeanCountInTokens($GameState, $opponent) + $opponentScore
  
  let $c := (
    copy $state := $GameState
    modify replace value of node $state//gameOver with 'true'
    return $state
  )
  
  (: Set the appropriate response message. :)
  let $updatedGameState := game:SetResponseMessage($c, '1', fn:concat($currentPlayer, ' won!'))
  
  let $result := (
    for $token in $updatedGameState//Token
      let $tokenId := xs:integer($token/@id)
    return (
      if($tokenId = $opponentMancala) then game:UpdateToken($token, $opponentScore)
      else(
        if($tokenId = $playerMancala) then game:UpdateToken($token, xs:integer($token))
        else game:UpdateToken($token, 0)
      )
    )
  )
  return game:UpdateTokensInGameState($updatedGameState,$result)
};

(: Returns the sum of all beans inside the holes of the specified player (excluding mancala). :)
declare %private function game:BeanCountInTokens($GameState as node(), $player as xs:string) as xs:integer {
  let $rangeStart := if ($player = 'Player 1') then 1 else 8
  let $rangeEnd := if($player = 'Player 1') then 6 else 13
  return (
   fn:sum(
      for $token in $GameState//Token
        let $tokenId := xs:integer($token/@id)
        where $tokenId >= $rangeStart and $tokenId <= $rangeEnd
      return xs:integer($token)
    )
  )
};

(:  Returns an empty GameState XML node with the <response> tag filled with the specified
    requestCode and requestMessage :)
declare %private function game:ReturnGameStateError($statusCode as xs:string, $statusMessage as xs:string)as node() {
  let $x := db:open('mancaladb','GameState.xml')
  return game:SetResponseMessage($x, $statusCode, $statusMessage)
};

declare %private function game:SetResponseMessage($gameState as node(), $statusCode as xs:string, $statusMessage as xs:string) as node() {
  copy $c := $gameState
  modify (
    replace value of node $c//statusCode with $statusCode,
    replace value of node $c//statusMessage with $statusMessage
  )
  return $c
};

(:  Returns a new GameState xml node based of the specified
    sessionId.
    The XML contains the initial manacala game values and randomly
    chooses which player starts. :)
declare %private function game:CreateNewGameState($sessionId as xs:string) as node() {
  let $currentPlayer := game:GetRandomPlayer()
  return (
    copy $x := db:open('mancaladb','GameState.xml')
    modify (
      replace value of node $x//sessionId with $sessionId,
      replace value of node $x//currentPlayer with $currentPlayer,
      replace value of node $x//gameOver with 'false',
      replace value of node $x//statusCode with '1',
      replace value of node $x//statusMessage with fn:concat($currentPlayer,' is up next!'),
      game:InitNewTokens($x)
    )
    return $x
  )
};

(:  Generates and returns a random sessionId which is a uuid hashed in md5. :)
declare %private function game:GenerateSessionId() as xs:hexBinary {
  let $uuid := random:uuid()
  let $hash := xs:hexBinary(hash:md5($uuid))
  return $hash
};

(:  Randomly returns either "Player 1" or "Player 2"
    Used when setting a new game to choose wo will start playing.  :)
declare %private function game:GetRandomPlayer() as xs:string {
  let $rand := random:integer(2)
  return if ($rand = 0) then 'Player 1' else 'Player 2'
};

(:  Initializes all Token nodes to 4 (4 beans at start of game)
    and all score tokens to 0 :)
declare %private %updating function game:InitNewTokens($GameState as node())  {
  for $t in $GameState//Token 
    return (
      if ($t/@id = '0') then
        replace value of node $t with '0'
    else 
      if ($t/@id = '7') then
        replace value of node $t with '0'
      else 
       replace value of node $t with '4'
    )
};



