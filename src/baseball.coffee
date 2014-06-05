# Description:
#   Pulls today's MLB games (and scores).
#
# Dependencies:
#   "moment": "^2.6.0"
#
# Commands:
#   hubot baseball - Pulls today's games
#   hubot baseball <team abbreviation> - Pulls today's game for a given team (ex. SF, NYY).
#
# Author:
#   jonursenbach

moment = require 'moment'

module.exports = (robot) =>
  robot.respond /baseball( (.*))?/i, (msg) ->
    team = if msg.match[1] then msg.match[1].toUpperCase().trim() else false
    today = moment()

    url = "http://gd2.mlb.com/components/game/mlb/year_#{today.format('YYYY')}/month_#{today.format('MM')}/day_#{today.format('DD')}/master_scoreboard.json"
    msg.http(url).get() (err, res, body) ->
      return msg.send "Unable to pull today's scoreboard. ERROR:#{err}" if err
      return msg.send "Unable to pull today's scoreboard: #{res.statusCode + ':\n' + body}" if res.statusCode != 200

      gameday = JSON.parse(body)
      games = gameday.data.games.game

      games.sort (a, b) ->
        if a.linescore
          return -1
        else if a.time < b.time
          return 1

        return 0

      emit = []
      for game in games
        awayTeamName = game.away_team_name
        homeTeamName = game.home_team_name

        if game.linescore
          linescore = game.linescore

          if displayGame(game, team)
            if !team
              emit.push("#{awayTeamName} (#{linescore.r.away}) vs #{homeTeamName} (#{linescore.r.home}) @ #{game.venue}")
              continue

            runs = linescore.r
            hits = linescore.h
            errors = linescore.e

            inningScores = {away: [], home: []}
            awayTeamName = padTeamName(game.away_team_name, game.home_team_name)
            homeTeamName = padTeamName(game.home_team_name, game.away_team_name)

            # If the game is just in the first inning, linecsore.home is an array. Past the first it becomes an array.
            if typeof linescore.inning.home != 'undefined' || typeof linescore.inning.away != 'undefined'
              inningScores.away.push(if linescore.inning.away then linescore.inning.away else ' ')
              inningScores.home.push(if linescore.inning.home then linescore.inning.home else ' ')
            else
              for inning in linescore.inning
                inningScores.away.push(if inning.away then inning.away else ' ')
                inningScores.home.push(if inning.home then inning.home else ' ')

            linescoreHeader = []
            linescoreHeader.push(Array(longestTeamName(awayTeamName, homeTeamName).length + 1).join(' '))
            if typeof linescore.inning.home != 'undefined' || typeof linescore.inning.away != 'undefined'
              linescoreHeader.push(1);
            else
              for inning of linescore.inning
                linescoreHeader.push(parseInt(inning)+1)

            # If there are less than 9 innings, we should pad out the linescore
            if linescoreHeader.length < 10
              for num in [linescoreHeader.length...10]
                linescoreHeader.push(num);
                inningScores.away.push(if inning.away then inning.away else ' ')
                inningScores.home.push(if inning.home then inning.home else ' ')

            gameLinescore = linescoreHeader.join(' | ') + " ‖ R | H | E\n"
            gameLinescore += awayTeamName + " | " + inningScores.away.join(' | ') + " ‖ #{runs.away} | #{hits.away} | #{errors.away}\n"
            gameLinescore += homeTeamName + " | " + inningScores.home.join(' | ') + " ‖ #{runs.home} | #{hits.home} | #{errors.home}"

            emit.push("```#{gameLinescore}```");
        else
          if displayGame(game, team)
            emit.push("#{awayTeamName} vs #{homeTeamName} @ #{game.venue} #{game.time}")

      if emit.length >= 1
        return msg.send emit.join("\n")

      msg.send "Sorry, I couldn't find any games today for #{team}."

longestTeamName = (away, home) ->
  if away.length > home.length
    return away
  else
    return home

padTeamName = (team1, team2) ->
  if team1.length < team2.length
    return team1 + Array((team2.length - team1.length) + 1).join(' ')
  else
    return team1

displayGame = (game, team) ->
  if !team || (team && game.home_name_abbrev == team || game.away_name_abbrev == team)
    return true

  return false
