  get "/newsletter/settings":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp genMain(c, genNewsletter(c))


  get "/newsletter/config":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp genMain(c, genNewsletterConfig(db, c))


  post "/newsletter/config/update":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"header", "header")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"css", "css")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"footer", "footer")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"confirm", "confirm")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"confirmEmail", "confirmEmail")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"welcome", "welcome")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"welcomeEmail", "welcomeEmail")
    exec(db, sql"UPDATE newsletter_settings SET value = ? WHERE element = ?", @"footer", "footer")

    redirect("/newsletter/config")


  get "/newsletter/signup":
    createTFD()
    resp genMain(c, genNewsletterSubscribe())


  post "/newsletter/signup":
    createTFD()
    if @"password2" != "": # DONT TOUCH, HoneyPot: https://github.com/ThomasTJdev/nim_websitecreator/issues/43#issue-403507393
      resp Http404

    when not defined(dev):
      when defined(recaptcha):
        if useCaptcha:
          if not await checkReCaptcha(@"g-recaptcha-response", c.req.ip):
            redirect("/error/" & encodeUrl("Error: You need to verify, that you are not a robot!"))

    resp genMain(c, genNewsletterMain(c, newsletterSignUp(db, @"email", @"name")))


  get "/newsletter/bulkadd":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp genMain(c, genNewsletterBulkadd())

  post "/newsletter/bulkadd":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    for line in split(@"bulkadd", "\n"):
      let data = split(line, ";")
      discard newsletterSignUp(db, data[0], data[1], true)

    redirect("/newsletter/subscribers")


  get "/newsletter/signup/confirm":
    createTFD()
    resp genMain(c, genNewsletterMain(c, newsletterSignConfirm(db, @"email", @"confirmcode")))


  get "/newsletter/unsubscribe":
    createTFD()
    resp genMain(c, genNewsletterMain(c, newsletterUnsubscribe(db, @"email", @"confirmcode")))


  post "/newsletter/sendtest":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    asyncCheck newsletterSendTest(db, @"subject", @"message", @"email")

    resp("OK")


  post "/newsletter/send":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    asyncCheck newsletterSendNewsletter(db, @"subject", @"message")

    resp("OK")


  get "/newsletter/mail":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp genMain(c, genNewsletterMail(db, c))


  get "/newsletter/mail/preview":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp newsletterGenMail(db, "test@test.test", @"message")


  get "/newsletter/subscribers":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp genMain(c, genNewsletterSubscribers(db, c))


  get "/newsletter/stats":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    resp genMain(c, genNewsletterStats(db, c))


  get "/newsletter/stats/view":
    createTFD()
    if not c.loggedIn or c.rank notin [Admin, Moderator]:
      redirect("/")

    let stat = getValue(db, sql"SELECT mailcontent FROM newsletter_stats WHERE id = ?", @"id")
    resp stat