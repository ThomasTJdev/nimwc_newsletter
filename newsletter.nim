# Copyright 2018 - Thomas T. Jarløv

import
  asyncdispatch,
  asyncnet,
  datetime2human,
  logging,
  os,
  osproc,
  parsecfg,
  random,
  sequtils,
  strutils,
  times,
  uri

when defined(postgres): import db_postgres
else:                   import db_sqlite

import ../../nimwcpkg/resources/email/email_connection
import ../../nimwcpkg/resources/session/user_data
import ../../nimwcpkg/resources/utils/logging_nimwc
import ../../nimwcpkg/resources/utils/plugins

let dict = loadConfig(replace(getAppDir(), "/nimwcpkg", "") & "/config/config.cfg")
let emailSupport = dict.getSectionValue("SMTP","SMTPEmailSupport")
let title = dict.getSectionValue("Server","title")
let website = dict.getSectionValue("Server","website")

proc pluginInfo() =
  let (n, v, d, u) = pluginExtractDetails("newsletter")
  echo " "
  echo "--------------------------------------------"
  echo "  Package:      " & n
  echo "  Version:      " & v
  echo "  Description:  " & d
  echo "  URL:          " & u
  echo "--------------------------------------------"
  echo " "
pluginInfo()



include "html.tmpl"


proc newsletterGenMail*(db: DbConn, email, message: string): string =
  let header = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "header")
  let css = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "css")
  let footer = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "footer")

  let headerFormat = header % [css]

  let confirmCode = getValue(db, sql"SELECT confirmCode FROM newsletter_subscribers WHERE email = ?", email)

  let footerFormat = footer % [email, confirmCode, website]

  return $(headerFormat & message & footerFormat)


proc newsletterSaveStats*(db: DbConn, subject, mailContent: string) =
  ## Save stats from newsletter

  let subscribers = getAllRows(db, sql"SELECT id FROM newsletter_subscribers WHERE status = ?", "confirmed").len()

  exec(db, sql"INSERT INTO newsletter_stats (subject, mailcontent, subscribers) VALUES (?, ?, ?)", subject, mailContent, subscribers)


proc newsletterSendTest*(db: DbConn, subject, message, email: string) {.async.} =
  ## Sends a testemail to the specified email

  asyncCheck sendMailNow(subject, newsletterGenMail(db, email, message), email)


proc newsletterSendNewsletter*(db: DbConn, subject, message: string) {.async.} =
  ## Sends a testemail to the specified email

  let header = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "header")
  let css = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "css")
  let footer = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "footer")
  let headerFormat = header % [css]

  let persons = getAllRows(db, sql"SELECT email, confirmCode, name FROM newsletter_subscribers WHERE status = ?", "confirmed")

  newsletterSaveStats(db, subject, headerFormat & message & footer)

  for person in persons:
    let footerFormat = footer % [person[0], person[1], website]

    let messageFormat = message % [person[2], person[0]]

    asyncCheck sendMailNow(subject, headerFormat & messageFormat & footerFormat, person[0])

    discard sleepAsync(200)


proc newsletterSignUp*(db: DbConn, email, name: string, bulkAdd = false): string =
  ## Sign up to newsletter

  let userExists = getValue(db, sql"SELECT id FROM newsletter_subscribers WHERE email = ?", email)

  if userExists != "":
    return "This email is already subscribed"

  let confirmCode = repeat($rand(10_00_00_00_00_00_00_00_00.int..int.high), 5).center(99, rand(toSeq('a'..'z')))

  if bulkAdd:
    exec(db, sql"INSERT INTO newsletter_subscribers (name, email, status, confirmCode) VALUES (?, ?, ?, ?)", name, email, "confirmed", confirmCode)
    return "OK"

  exec(db, sql"INSERT INTO newsletter_subscribers (name, email, status, confirmCode) VALUES (?, ?, ?, ?)", name, email, "unconfirmed", confirmCode)

  let confirmMsg = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "confirm")
  let confirmEmail = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "confirmEmail")

  let confirmLink = website & "/newsletter/signup/confirm?email=" & email & "&confirmcode=" & confirmCode

  let message = confirmEmail % [name, title, confirmLink]

  asyncCheck sendMailNow(title & " - Confirm email", newsletterGenMail(db, email, message), email)

  when defined(adminnotify):
    let subscriberUrl = "<a href=\"" & website & "/newsletter/subscribers\">subscribers</a>"
    let adminMessage = """There's a new subscriber to your newsletter!
    <br>
    <br>
    $1 has registered with $2 at $3.
    <br>
    <br>
    You can with all the subscribers at $4.
    <br>""" % [name, email, $now(), subscriberUrl]

    asyncCheck sendAdminMailNow("New subscriber", adminMessage)

  return confirmMsg


proc newsletterSignConfirm*(db: DbConn, email, confirmCodeUser: string): string =
  ## Confirm newsletter

  let userID = getValue(db, sql"SELECT id FROM newsletter_subscribers WHERE email = ? and status = ?", email, "unconfirmed")

  if userID == "":
    return "This email is not registrated to the newsletter"

  let confirmCode = getValue(db, sql"SELECT confirmCode FROM newsletter_subscribers WHERE id = ?", userID)

  if confirmCode == confirmCodeUser:

    exec(db, sql"UPDATE newsletter_subscribers SET status = ? WHERE id = ?", "confirmed", userID)

    let welcome = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "welcome")
    let welcomeEmail = getValue(db, sql"SELECT value FROM newsletter_settings WHERE element = ?", "welcomeEmail")
    let userName = getValue(db, sql"SELECT name FROM newsletter_subscribers WHERE id = ?", userID)

    if welcomeEmail == "":
      return welcome
    else:
      let message = welcomeEmail % [userName, title]
      asyncCheck sendMailNow(title & " - welcome!", newsletterGenMail(db, email, message), email)
      return welcome

  else:
    return "An error occurred. Please contact the <a href=\"mailto:" & emailSupport & "\">" & emailSupport & "</a>."


proc newsletterUnsubscribe*(db: DbConn, email, confirmCodeUser: string): string =
  ## Unsubscribe newsletter

  let userID = getValue(db, sql"SELECT id FROM newsletter_subscribers WHERE email = ? and confirmCode = ?", email, confirmCodeUser)

  if userID != "":
    exec(db, sql"DELETE FROM newsletter_subscribers WHERE id = ?", userID)
    return "You have been removed from the newsletter"
  else:
    return "Your user was not found. Please send a mail to <a href=\"mailto:" & emailSupport & "\">, and we'll delete your email manually"



const header = """<!DOCTYPE html>
<html lang=EN style="3D&quot;background:#FAFAFA;min-height:100%=">
<head>
  <meta charset=UTF-8>
  <meta content="width=device-width, initial-scale=1.0" name=viewport>
  <title></title>
  $1
</head>
<body style="font-size: 16px;font-family:'Roboto','Open Sans', 'Helvetica Neue', Helvetica, sans-serif;font-style:normal;font-weight:400;src:local('Roboto'),local('Roboto-Regular'),url(https://fonts.gstatic.com/s/roboto/v18/CWB0XYA8bzo0kSThX0UTuA.woff2) format('woff2');unicode-range:U+0000-00FF,U+0131,U+0152-0153,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2074,U+20AC,U+2212,U+2215">
  <div style=background:#ededed;border-color:#123d6d;height:70px;width:100%;margin-bottom:20px;padding-top:5px;padding-bottom:5px;text-align:center>
      <a href="https://nimwc.org">
        <img src="https://nimwc.org/images/logo/NimWC_logo_blue.png" alt="NimWC" />
      </a>
  </div>
  <div style="padding:0 10px">"""

const footer = """</div>
  <div style="text-align: center;font-style: italic;margin-top:20px;">
    <p style="margin-bottom: 0;">
      <a href="$3/newsletter/unsubscribe?email=$1&confirmcode=$2">Unsubscribe</a>
    </p>
  </div>
  <div style="background:#171921;border-color:#123d6d;height:35px;width:100%;margin-top:5px;text-align:center">
    <div style="height:100%;font-size:18px;margin-left:15px;line-height:36px">
      <a href="https://nimwc.org" style="color:white">www.nimwc.org</a>
    </div>
  </div>
</body>
</html>"""

const css = """<style>table{border-spacing: 0;}</style>"""

const confirm = "Thank you for registrating. We have send you a confirmation email. Please click on the link in the email to activate your account."

const confirmEmail = """Welcome $1
<br><br>
Please click on the link below to subscribe to $2 newsletter.
<br><br>
<b>Confirmation link:</b>
<br>
<a href="$3">$3</a>
<br>"""

const welcome = """Welcome. Thank you for signing up!"""

const
  sql_now =
    when defined(postgres): "(extract(epoch from now()))" # Postgres epoch.
    else:                   "(strftime('%s', 'now'))"     # SQLite 3 epoch.

  sql_timestamp =
    when defined(postgres): "integer"   # is internally Hardcoded to UTC anyways
    else:                   "timestamp" # SQLite 3 Timestamp.

  sql_id = # http://blog.2ndquadrant.com/postgresql-10-identity-columns
    when defined(postgres): "integer generated by default as identity"
    else:                   "integer"     # SQLite 3 integer ID.

  newsletterSettings = sql("""
    create table if not exists newsletter_settings (
      id         $3            primary key,
      element    TEXT          NOT NULL,
      value      TEXT          NOT NULL,
      creation   $2            NOT NULL           default $1,
      modified   $2            NOT NULL           default $1
    );""".format(sql_now, sql_timestamp, sql_id))

  newsletterSubscribers = sql("""
    create table if not exists newsletter_subscribers (
      id         $3            primary key,
      name       VARCHAR(60)   NOT NULL,
      email      VARCHAR(254)  NOT NULL           unique,
      status     VARCHAR(30)   NOT NULL,
      confirmCode  VARCHAR(250),
      creation   $2            NOT NULL           default $1,
      modified   $2            NOT NULL           default $1
    );""".format(sql_now, sql_timestamp, sql_id))

  newsletterStats = sql("""
    create table if not exists newsletter_stats (
      id         $3            primary key,
      subject     TEXT         NOT NULL,
      mailcontent TEXT         NOT NULL,
      subscribers INTEGER      NOT NULL,
      creation   $2            NOT NULL           default $1,
      modified   $2            NOT NULL           default $1
    );""".format(sql_now, sql_timestamp, sql_id))

proc newsletterStart*(db: DbConn) =
  ## Required proc. Will run on each program start
  ##
  ## If there's no need for this proc, just
  ## discard it. The proc may not be removed.

  info("Newsletter plugin: Updating database with Newsletter table if not exists")

  if not db.tryExec(newsletterSettings):
    info("Newsletter plugin: Newsletter settings table created in database")
  else:
    if getAllRows(db, sql"SELECT id FROM newsletter_settings").len() == 0:
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "header", header)
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "css", css)
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "footer", footer)
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "confirm", confirm)
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "confirmEmail", confirmEmail)
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "welcome", welcome)
      exec(db, sql"INSERT INTO newsletter_settings (element, value) VALUES (?, ?)", "welcomeEmail", "")

  if not db.tryExec(newsletterSubscribers):
    info("Newsletter plugin: Newsletter subscribers table created in database")

  if not db.tryExec(newsletterStats):
    info("Newsletter plugin: Newsletter stats table created in database")
