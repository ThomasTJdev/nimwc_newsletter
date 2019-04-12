/*
    Initialize Codemirror editor
*/
$(function() {
  if($('#message').length > 0 ){
    var editor = CodeMirror.fromTextArea($('#message')[0], {
      lineNumbers: true,
      lineWrapping: true,
      mode: "htmlmixed",
      autoCloseTags: true,
      tabSize: 2,
      indentWithTabs: false,
      matchTags: {bothTags: true},
      extraKeys: {"Ctrl-J": "toMatchingTag"}
    });
    editor.on('change', function () {
      $("#save").attr("data-ischanged", "1");
      editor.save();
    });

    CodeMirror.commands["selectAll"](editor);
    function getSelectedRange() {
      return { from: editor.getCursor(true), to: editor.getCursor(false) };
    }

    function autoFormatSelection() {
      var range = getSelectedRange();
      editor.autoFormatRange(range.from, range.to);
      $("#save").attr("data-ischanged", "0");
    }
  }

  $(".newsletterView").click(function() {
    $("form").submit();
  });
  $(".newsletterSend").click(function() {
    newsletterSend("false");
  });
  $(".newsletterTest").click(function() {
    newsletterSend("true");
  });
});


function newsletterSend(test) {
  var result = confirm("Send newsletter?");
  if (result) {

    var url = "/newsletter/send";
    if (test == "true") {
      url = "/newsletter/sendtest";
    }

    var email = $(".testemail").val();
    var message = $("#message").val();
    var subject = $(".subject").val();
    
    var data = {email: email, subject: subject, message: message}

    $.ajax({
      url: url,
      type: 'POST',
      data: data,
      success: function(response) {
        if (response == "OK") {
          if (test == "true") {
            $("#save").attr("data-ischanged", "0");
            $("#notifySaved").css("top", "50%");
            $("#notifySaved").text("Mail sent");
            $("#notifySaved").show(400);
            setTimeout(function(){
              $("#notifySaved").hide(400);
            }, 1200);
          } else {
            window.location.href = "/newsletter/stats";
          }
        } else {
          $("#notifySaved").css("background", "#cb274bde");
          $("#notifySaved").css("top", "50%");
          $("#notifySaved").text(response);
          $("#notifySaved").show(400);
          setTimeout(function(){
            $("#notifySaved").hide(400);
            $("#notifySaved").css("background", "#27cb4ede");
          }, 1700);
        }
      }
    });
  }
}