# --------------------- LIBRARIES ---------------------
library(shiny)
library(shinyjs)
library(DBI)
library(RPostgres)  # Swapped from RMySQL
library(pool)
library(sodium)

# --------------------- DATABASE CONNECTION ---------------------
# This pulls the data from the Environment Variables you set in Render
pool <- dbPool(
  RPostgres::Postgres(),
  hostname = Sys.getenv("DB_HOST"),  # Uses 'dpg-...-a' on Render
  port     = as.integer(Sys.getenv("DB_PORT")),
  dbname   = Sys.getenv("DB_NAME"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)

onStop(function() {
  poolClose(pool)
})

# --------------------- 1. LOGIN UI ---------------------
login_ui <- div(
  class = "login-container",
  div(class = "login-box",
      h2("Paw Feed", class = "login-logo"),
      p("Welcome back, human", class = "login-subtitle"),
      
      div(class = "form-group",
          tags$label("Email"),
          textInput("user_email", NULL, placeholder = "Enter your email")
      ),
      
      div(class = "form-group",
          tags$label("Password"),
          passwordInput("user_password", NULL, placeholder = "••••••••")
      ),
      
      actionButton("login_btn", "Sign In", class = "btn-login"),
  )
)

# --------------------- 2. DASHBOARD UI ---------------------
dashboard_ui <- tagList(
  div(id = "dropdownModal", class = "dropdown-modal",
      div(class = "form-header",
          div(class = "form-actions", actionButton("cancelForm", "Cancel", class = "cancel-btn")),
          h2("Add Pet Sched"),
          div(class = "form-actions", actionButton("saveForm", "Save", class = "save-btn"))
      ),
      
      div(class = "form-group",
          tags$label("Pet name"),
          textInput("petName", label = NULL, placeholder = "Example: Bogart")
      ),
      
      div(class = "form-group",
          tags$label("Pet Age"),
          {
            input_tag <- numericInput("petAge", label = NULL, value = NA, min = 0)
            input_tag$children[[2]] <- tagAppendAttributes(input_tag$children[[2]], placeholder = "Example: 3")
            input_tag
          }
      ),
      
      div(class = "form-group pet-type-container",
          tags$label("Pet Type", class = "form-label"),
          div(class = "pet-type-selector",
              radioButtons(inputId = "petType", 
                           label = NULL, 
                           inline = TRUE,
                           choices = list(
                             "🐶 Dog" = "dog", 
                             "🐱 Cat" = "cat", 
                             "🐰 Rabbit" = "rabbit", 
                             "✨ Others" = "others"
                           ),
                           selected = character(0))
          ),
          hidden(
            div(id = "otherTypeDiv", class = "other-input-wrapper",
                textInput("petTypeOther", label = NULL, placeholder = "Specify breed or type...")
            )
          )
      ),
      
      div(class = "form-group",
          tags$label("Feeding Time"),
          div(class = "time-input-wrapper",
              div(id = "timeList", class = "time-list"),
              tags$input(type = "time", id = "feedingTimeInput", class = "form-control"),
              actionButton("addTime", "+ Add Time", class = "add-time-btn")
          )
      )
  ),
  
  div(class = "main-container",
      div(class = "header-wrapper",
          div(class = "header",
              div(class = "logo-section",
                  tags$img(src = "logo.png", class = "header-logo"), 
                  div(class = "brand-text",
                      h1("Paw Feed"),
                      span(class = "tagline", "Where Care Meets Time") 
                  )
              ),
              div(class = "header-buttons",
                  actionButton("logout_btn", "Logout", class = "btn-logout-minimal"),
                  actionButton("add_pet_header", "Add Pet +", class = "add-pet-header-btn"),
                  actionButton("install_pwa", "📱 Install App", class = "btn-install", 
                               id = "installBtn", style = "display: none;")
              )
          )
      ),
      uiOutput("petDisplay")
  )
)

# --------------------- 3. MAIN UI (SHELL) ---------------------
ui <- fluidPage(
  useShinyjs(),
  includeCSS("www/fone.css"),
  
  div(id = "dropdownOverlay", class = "dropdown-overlay"),
  
  tags$script(HTML("
    var alarmAudio = null;
    var deferredPrompt = null;
    
    // PWA Install Detection
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredPrompt = e;
      document.getElementById('installBtn').style.display = 'block';
    });
    
    // Register Service Worker
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js')
        .then(registration => console.log('Service Worker registered'))
        .catch(err => console.log('Service Worker registration failed:', err));
    }
    
    // Request Notification Permission
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
    
    function updateCardStyle(petId, isChecked) {
      var card = document.getElementById('card_' + petId);
      if (card) {
        if (isChecked) {
          card.classList.remove('alarm-inactive');
          card.classList.add('alarm-active');
        } else {
          card.classList.remove('alarm-active');
          card.classList.add('alarm-inactive');
        }
      }
    }
    
    function playAlarmSound(soundType) {
      if (alarmAudio) {
        alarmAudio.pause();
        alarmAudio = null;
      }
      
      var soundFile = 'default_beep.mp3';
      if (soundType === 'chime') soundFile = 'chime.mp3';
      else if (soundType === 'bark') soundFile = 'bark.mp3';
      else if (soundType === 'meow') soundFile = 'meow.mp3';
      else if (soundType === 'birds') soundFile = 'birds.mp3';
      
      alarmAudio = new Audio(soundFile);
      alarmAudio.loop = true;
      alarmAudio.play().catch(function(error) {
        console.log('Audio playback failed:', error);
      });
    }
    
    function stopAlarmSound() {
      if (alarmAudio) {
        alarmAudio.pause();
        alarmAudio.currentTime = 0;
        alarmAudio = null;
      }
    }
    
    // Install PWA function
    function installPWA() {
      if (deferredPrompt) {
        deferredPrompt.prompt();
        deferredPrompt.userChoice.then((choiceResult) => {
          if (choiceResult.outcome === 'accepted') {
            console.log('PWA installed');
            document.getElementById('installBtn').style.display = 'none';
          }
          deferredPrompt = null;
        });
      }
    }
    
    Shiny.addCustomMessageHandler('playAlarm', function(data) {
      playAlarmSound(data.sound);
      
      // Send browser notification
      if ('Notification' in window && Notification.permission === 'granted') {
        new Notification('🔔 Feeding Time!', {
          body: data.petName + ' is hungry!',
          icon: 'icon-192.png',
          badge: 'icon-192.png',
          tag: 'feeding-alarm',
          requireInteraction: true
        });
      }
    });
    
    Shiny.addCustomMessageHandler('stopAlarm', function(message) {
      stopAlarmSound();
    });
    
    Shiny.addCustomMessageHandler('updateBadge', function(count) {
      if ('setAppBadge' in navigator) {
        if (count > 0) {
          navigator.setAppBadge(count);
        } else {
          navigator.clearAppBadge();
        }
      }
    });

    Shiny.addCustomMessageHandler('setCookie', function(data) {
      document.cookie = data.name + '=' + data.value + '; path=/; max-age=86400';
    });

    Shiny.addCustomMessageHandler('clearCookie', function(name) {
      document.cookie = name + '=; Max-Age=-99999999; path=/;';
    });

    $(document).on('shiny:connected', function(event) {
      var cookieValue = document.cookie.split('; ').find(row => row.startsWith('pawfeed_user='));
      if (cookieValue) {
        var email = cookieValue.split('=')[1];
        Shiny.setInputValue('cookie_login', email);
      }
    });
  ")),
  
  uiOutput("page_content")
)

# --------------------- SERVER LOGIC ---------------------
server <- function(input, output, session) {
  auth <- reactiveValues(logged_in = FALSE, user_info = NULL)
  feedingTimes <- reactiveVal(character(0))
  refreshTrigger <- reactiveVal(0)
  lastAlarmCheck <- reactiveVal(NULL)
  # NEW: Store temporary edit modal data
  editModalData <- reactiveValues(
    pet_id = NULL,
    pet_name = NULL,
    times = list(),
    deleted_schedules = c(),
    new_times = c()
  )
  
  observeEvent(input$cookie_login, {
    req(input$cookie_login)
    user_query <- dbGetQuery(pool, sprintf(
      "SELECT * FROM users WHERE email = %s", 
      dbQuoteString(pool, input$cookie_login)
    ))
    
    if (nrow(user_query) == 1) {
      auth$logged_in <- TRUE
      auth$user_info <- user_query
    } else {
      auth$logged_in <- FALSE
    }
  })
  
  observe({
    invalidateLater(500, session)
    if (is.na(auth$logged_in)) {
      auth$logged_in <- FALSE
    }
  })
  
  output$page_content <- renderUI({
    if (is.na(auth$logged_in)) {
      return(div(class = "loading-screen", div(class = "loader")))
    } else if (auth$logged_in == FALSE) {
      return(login_ui)
    } else {
      return(dashboard_ui)
    }
  })
  
  observeEvent(input$login_btn, {
    req(input$user_email, input$user_password)
    
    user_query <- dbGetQuery(pool, sprintf(
      "SELECT * FROM users WHERE email = %s", 
      dbQuoteString(pool, input$user_email)
    ))
    
    if (nrow(user_query) == 1) {
      if (password_verify(user_query$password_hash, input$user_password)) {
        auth$logged_in <- TRUE
        auth$user_info <- user_query
        session$sendCustomMessage("setCookie", list(name = "pawfeed_user", value = input$user_email))
        showNotification("Welcome back!", type = "message")
      } else {
        showNotification("Invalid password", type = "error")
      }
    } else {
      showNotification("User not found", type = "error")
    }
  })
  
  observeEvent(input$logout_btn, {
    auth$logged_in <- FALSE
    auth$user_info <- NULL
    session$sendCustomMessage("clearCookie", "pawfeed_user")
    showNotification("Logged out", type = "message")
  })
  
  observeEvent(input$petType, {
    req(input$petType)
    if (input$petType == "others") {
      showElement("otherTypeDiv")
    } else {
      hideElement("otherTypeDiv")
      updateTextInput(session, "petTypeOther", value = "")
    }
  })
  
  observeEvent(input$add_pet_header, {
    addClass("dropdownModal", "show")
    addClass("dropdownOverlay", "show")
  })
  
  observeEvent(input$addTime, {
    runjs('Shiny.setInputValue("lastTimeAdded", document.getElementById("feedingTimeInput").value, {priority: "event"});')
  })
  
  observeEvent(input$lastTimeAdded, {
    newTime <- input$lastTimeAdded
    req(newTime != "")
    
    current <- feedingTimes()
    if (!(newTime %in% current)) {
      updated <- c(current, newTime)
      feedingTimes(updated)
      
      displayTime <- format(as.POSIXct(paste("2024-01-01", newTime)), "%I:%M %p")
      safe_id <- gsub(":", "", newTime)
      insertUI(
        selector = "#timeList",
        where = "beforeEnd",
        ui = div(class = "added-time-pill", id = paste0("item_", safe_id),
                 span(class = "pill-text", displayTime),
                 actionButton(paste0("rem_", safe_id), "×", 
                              class = "remove-pill-btn",
                              onclick = sprintf("Shiny.setInputValue('removeTimeClick', '%s', {priority: 'event'})", newTime)))
      )
    }
  })
  
  observeEvent(input$removeTimeClick, {
    t <- input$removeTimeClick
    feedingTimes(setdiff(feedingTimes(), t))
    removeUI(selector = paste0("#item_", gsub(":", "", t)))
  })
  
  # --- EDIT SETTINGS MODAL ---
  observeEvent(input$editPetAlarm, {
    pet_id <- input$editPetAlarm
    
    pet_data <- dbGetQuery(pool, sprintf("
        SELECT p.name, p.age, s.repeat_daily, s.sound_type, s.feed_time, s.sched_id
        FROM pets p 
        LEFT JOIN feeding_schedules s ON p.pet_id = s.pet_id 
        WHERE p.pet_id = %d", pet_id))
    
    req(nrow(pet_data) > 0)
    
    # Initialize edit modal data
    editModalData$pet_id <- pet_id
    editModalData$pet_name <- pet_data$name[1]
    editModalData$deleted_schedules <- c()
    editModalData$new_times <- c()
    
    # Store existing times with their schedule IDs
    editModalData$times <- list()
    if (!is.na(pet_data$sched_id[1])) {
      for (i in 1:nrow(pet_data)) {
        editModalData$times[[as.character(pet_data$sched_id[i])]] <- list(
          sched_id = pet_data$sched_id[i],
          feed_time = pet_data$feed_time[i]
        )
      }
    }
    
    has_schedules <- !is.na(pet_data$sched_id[1])
    is_repeating <- if(has_schedules) as.logical(pet_data$repeat_daily[1]) else FALSE
    current_sound <- if(has_schedules) pet_data$sound_type[1] else "beep"
    
    showModal(modalDialog(
      title = NULL, fade = TRUE, size = "m", easyClose = TRUE,
      div(class = "dark-modal-content edit-pet-modal",
          div(class = "modal-header-custom",
              h2(paste("Edit", pet_data$name[1])),
          ),
          
          div(class = "modal-scroll-body",
              div(class = "custom-input-group", style = "margin-bottom:15px",
                  tags$label("Pet Name"),
                  textInput("editPetName", NULL, value = pet_data$name[1])
              ),
              
              div(class = "custom-input-group",
                  tags$label(tags$i(class = "far fa-clock"), style = "margin-bottom:15px", " Feeding Times"),
                  div(id = "modalTimeEditor",
                      if(has_schedules) {
                        lapply(1:nrow(pet_data), function(i) {
                          div(class = "time-edit-row", id = paste0("row_", pet_data$sched_id[i]),
                              tags$input(type = "time", class = "form-control time-input-dark", 
                                         id = paste0("time_", pet_data$sched_id[i]),
                                         value = pet_data$feed_time[i]),
                              actionButton(paste0("del_ui_", pet_data$sched_id[i]), "×", 
                                           class = "btn-remove-time",
                                           onclick = sprintf("Shiny.setInputValue('markScheduleForDeletion', %d, {priority: 'event'})", 
                                                             pet_data$sched_id[i]))
                          )
                        })
                      } else {
                        p(style="color:#666; font-style:italic;", "No schedules found. Add one below.")
                      }
                  ),
                  tags$input(type = "time", id = "newTimeInput", class = "form-control time-input-dark", style = "margin-top: 10px;"),
                  actionButton("addMoreTimeEdit", "+ Add Time", class = "btn-link-gold", style = "margin-bottom:25px")
              ),
              
              div(class = "settings-row",
                  div(class = "settings-info", 
                      div(class = "icon-circle-purple", tags$i(class = "fas fa-sync-alt")),
                      div(class = "text-stack",
                          span(class = "setting-title", "Repeat Daily"),
                          span(class = "setting-subtitle", "Alarm repeats every day")
                      )
                  ),
                  div(class = "alarm-toggle",
                      tags$input(type = "checkbox", id = "editRepeatDaily", 
                                 checked = if(is_repeating) "checked" else NULL),
                      tags$label(`for` = "editRepeatDaily", class = "switch")
                  )
              ),
              
              div(class = "custom-input-group",  style = "margin-bottom:55px",
                  tags$label(tags$i(class = "fas fa-volume-up"), " Alarm Sound"),
                  div(class = "sound-selector-group",
                      radioButtons("editAlarmSound", NULL, 
                                   choices = c("Bell" = "default_beep", "Chime" = "chime", "Bark" = "bark", "Meow" = "meow", "Birds" = "birds"),
                                   selected = pet_data$sound_type[1], inline = TRUE)
                  )
              )
          ),
          
          div(class = "modal-footer-custom", style="display:flex; justify-content: space-between",
              actionButton("deletePetTotal", "Delete Pet", class = "btn-delete-alarm",
                           onclick = sprintf("Shiny.setInputValue('deletePetConfirm', %d)", pet_id)),
              div(class = "footer-right",
                  actionButton("dismissModal", "Dismiss", 
                               class = "btn-dismiss", 
                               `data-dismiss` = "modal"),
                  actionButton("saveAlarmSettings", "Apply Changes", class = "btn-apply-changes",
                               onclick = sprintf("Shiny.setInputValue('targetPetId', %d)", pet_id))
              )
          )
      ), footer = NULL
    ))
  })
  
  # --- ADD TIME IN EDIT MODAL (Only add to UI, not DB yet) ---
  observeEvent(input$addMoreTimeEdit, {
    new_time <- NULL
    runjs('
      var timeVal = document.getElementById("newTimeInput").value;
      if (timeVal) {
        Shiny.setInputValue("newTimeFromModal", timeVal, {priority: "event"});
        document.getElementById("newTimeInput").value = "";
      }
    ')
  })
  
  observeEvent(input$newTimeFromModal, {
    new_time <- input$newTimeFromModal
    req(new_time != "")
    
    # Add to temporary storage
    temp_id <- paste0("new_", length(editModalData$new_times) + 1)
    editModalData$new_times <- c(editModalData$new_times, new_time)
    
    displayTime <- format(as.POSIXct(paste("2024-01-01", new_time)), "%I:%M %p")
    
    # Add to UI only
    insertUI(
      selector = "#modalTimeEditor",
      where = "beforeEnd",
      ui = div(class = "time-edit-row", id = paste0("row_", temp_id),
               tags$input(type = "time", class = "form-control time-input-dark", 
                          id = paste0("time_", temp_id),
                          value = new_time),
               actionButton(paste0("del_ui_", temp_id), "×", 
                            class = "btn-remove-time",
                            onclick = sprintf("Shiny.setInputValue('removeNewTime', '%s', {priority: 'event'})", temp_id))
      )
    )
  })
  
  # --- MARK SCHEDULE FOR DELETION (Don't delete from DB yet) ---
  observeEvent(input$markScheduleForDeletion, {
    sched_id <- input$markScheduleForDeletion
    req(sched_id)
    
    # Add to deletion list
    editModalData$deleted_schedules <- c(editModalData$deleted_schedules, sched_id)
    
    # Remove from UI
    removeUI(selector = paste0("#row_", sched_id))
  })
  
  # --- REMOVE NEW TIME (from UI only) ---
  observeEvent(input$removeNewTime, {
    temp_id <- input$removeNewTime
    req(temp_id)
    
    # Remove from temporary storage
    idx <- which(names(editModalData$new_times) == temp_id)
    if (length(idx) > 0) {
      editModalData$new_times <- editModalData$new_times[-idx]
    }
    
    # Remove from UI
    removeUI(selector = paste0("#row_", temp_id))
  })
  
  # --- SAVE MODAL SETTINGS (Now saves everything at once) ---
  observeEvent(input$saveAlarmSettings, {
    req(input$targetPetId)
    
    tryCatch({
      con <- poolCheckout(pool)
      
      # 1. Update pet name if changed
      if (input$editPetName != editModalData$pet_name) {
        dbExecute(con, sprintf(
          "UPDATE pets SET name = %s WHERE pet_id = %d",
          dbQuoteString(con, input$editPetName),
          as.integer(input$targetPetId)
        ))
      }
      
      # 2. Delete marked schedules
      if (length(editModalData$deleted_schedules) > 0) {
        for (sched_id in editModalData$deleted_schedules) {
          dbExecute(con, sprintf(
            "DELETE FROM feeding_schedules WHERE sched_id = %d", 
            as.integer(sched_id)
          ))
        }
      }
      
      # 3. Update existing schedule times
      for (sched_id in names(editModalData$times)) {
        time_input_id <- paste0("time_", sched_id)
        new_time <- input[[time_input_id]]
        
        if (!is.null(new_time) && new_time != "") {
          dbExecute(con, sprintf(
            "UPDATE feeding_schedules SET feed_time = %s WHERE sched_id = %d",
            dbQuoteString(con, paste0(new_time, ":00")),
            as.integer(sched_id)
          ))
        }
      }
      
      # 4. Insert new times
      if (length(editModalData$new_times) > 0) {
        for (new_time in editModalData$new_times) {
          dbExecute(con, sprintf(
            "INSERT INTO feeding_schedules (pet_id, feed_time, repeat_daily, sound_type, is_active) 
             VALUES (%d, %s, %d, %s, 1)",
            as.integer(input$targetPetId),
            dbQuoteString(con, paste0(new_time, ":00")),
            as.integer(input$editRepeatDaily),
            dbQuoteString(con, input$editAlarmSound)
          ))
        }
      }
      
      # 5. Update repeat_daily and sound_type for all schedules of this pet
      dbExecute(con, sprintf(
        "UPDATE feeding_schedules SET repeat_daily = %d, sound_type = %s WHERE pet_id = %d",
        as.integer(input$editRepeatDaily),
        dbQuoteString(con, input$editAlarmSound),
        as.integer(input$targetPetId)
      ))
      
      poolReturn(con)
      
      removeModal()
      showNotification("Settings updated successfully!", type = "message")
      refreshTrigger(refreshTrigger() + 1)
      
    }, error = function(e) {
      if(exists("con")) poolReturn(con)
      showNotification(paste("Update Error:", e$message), type = "error")
    })
  })
  
  # --- ALARM TOGGLE LOGIC ---
  observeEvent(input$toggleAlarm, {
    req(input$toggleAlarm)
    dbExecute(pool, sprintf("UPDATE feeding_schedules SET is_active = %d WHERE pet_id = %d", 
                            as.integer(input$toggleAlarm$status), 
                            as.numeric(input$toggleAlarm$id)))
  })
  
  # --- DELETE PET ---
  observeEvent(input$deletePetConfirm, {
    pet_id <- input$deletePetConfirm
    dbExecute(pool, sprintf("DELETE FROM feeding_schedules WHERE pet_id = %d", pet_id))
    dbExecute(pool, sprintf("DELETE FROM pets WHERE pet_id = %d", pet_id))
    removeModal()
    refreshTrigger(refreshTrigger() + 1)
    showNotification("Pet removed.", type = "warning")
  })
  
  # --- SAVE NEW PET FORM ---
  observeEvent(input$saveForm, {
    sched_times <- feedingTimes()
    pet_type_selected <- if(!is.null(input$petType)) input$petType else ""
    final_pet_type <- if (pet_type_selected == "others") input$petTypeOther else pet_type_selected
    
    if (input$petName == "" || is.na(input$petAge) || pet_type_selected == "" || 
        (pet_type_selected == "others" && input$petTypeOther == "")) {
      showNotification("Please fill in all pet details.", type = "error")
      return()
    }
    
    if (length(sched_times) == 0) {
      showNotification("Please add at least one feeding time!", type = "warning")
      return()
    }
    
    tryCatch({
      con <- poolCheckout(pool)
      dbExecute(con, sprintf(
        "INSERT INTO pets (name, type, age) VALUES (%s, %s, %d)",
        dbQuoteString(con, input$petName),
        dbQuoteString(con, final_pet_type),
        as.integer(input$petAge)
      ))
      new_id <- as.numeric(dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[1])
      for (t in sched_times) {
        dbExecute(con, sprintf(
          "INSERT INTO feeding_schedules (pet_id, feed_time) VALUES (%d, %s)",
          as.integer(new_id),
          dbQuoteString(con, paste0(t, ":00"))
        ))
      }
      poolReturn(con)
      showNotification(paste("Success!", input$petName, "added."), type = "message")
      refreshTrigger(refreshTrigger() + 1)
      removeClass("dropdownModal", "show")
      removeClass("dropdownOverlay", "show")
      updateTextInput(session, "petName", value = "")
      updateNumericInput(session, "petAge", value = NA)
      updateRadioButtons(session, "petType", selected = character(0))
      updateTextInput(session, "petTypeOther", value = "")
      feedingTimes(character(0))
      removeUI(selector = ".added-time-pill", multiple = TRUE)
    }, error = function(e) {
      if(exists("con")) poolReturn(con)
      showNotification(paste("Database Error:", e$message), type = "error")
    })
  })
  
  # --- Alarm Logic ---
  observeEvent(input$cancelForm, {
    removeClass("dropdownModal", "show")
    removeClass("dropdownOverlay", "show")
  })
  
  
  observe({
    req(auth$logged_in)
    invalidateLater(5000, session) # Check every 5 seconds
    
    current_time <- format(Sys.time(), "%H:%M:%S")
    current_minute <- substr(current_time, 1, 5)
    
    # Prevent duplicate alarms within the same minute
    if (!is.null(lastAlarmCheck()) && lastAlarmCheck() == current_minute) {
      return()
    }
    
    # Get all active schedules
    active_schedules <- dbGetQuery(pool, sprintf("
      SELECT p.pet_id, p.name, s.feed_time, s.sound_type, s.repeat_daily
      FROM pets p
      INNER JOIN feeding_schedules s ON p.pet_id = s.pet_id
      WHERE s.is_active = 1
    "))
    
    if (nrow(active_schedules) > 0) {
      for (i in 1:nrow(active_schedules)) {
        schedule_time <- substr(active_schedules$feed_time[i], 1, 5)
        
        if (schedule_time == current_minute) {
          # Trigger alarm
          pet_name <- active_schedules$name[i]
          sound_type <- active_schedules$sound_type[i]
          
          # Play sound
          session$sendCustomMessage("playAlarm", list(sound = sound_type))
          
          # Show modal
          showModal(modalDialog(
            title = NULL,
            size = "m",
            easyClose = FALSE,
            div(class = "alarm-modal-content",
                div(class = "alarm-icon", "🔔"),
                h2(paste("Time to feed", pet_name, "!")),
                p(class = "alarm-time", format(Sys.time(), "%I:%M %p")),
                div(class = "alarm-actions",
                    actionButton("dismissAlarm", "Fed ✓", class = "btn-fed"),
                    actionButton("snoozeAlarm", "Snooze 5 min", class = "btn-snooze")
                )
            ),
            footer = NULL
          ))
          
          lastAlarmCheck(current_minute)
          break # Only show one alarm at a time
        }
      }
    }
  })
  
  # Dismiss alarm
  observeEvent(input$dismissAlarm, {
    session$sendCustomMessage("stopAlarm", list())
    removeModal()
    showNotification("Marked as fed!", type = "message")
  })
  
  # Snooze alarm
  observeEvent(input$snoozeAlarm, {
    session$sendCustomMessage("stopAlarm", list())
    removeModal()
    showNotification("Snoozed for 5 minutes", type = "message")
    
    # Reset alarm check to allow re-trigger in 5 minutes
    invalidateLater(300000, session)
    isolate({ lastAlarmCheck(NULL) })
  })
  # --- DASHBOARD DISPLAY ---
  output$petDisplay <- renderUI({
    refreshTrigger() 
    pets <- dbGetQuery(pool, "SELECT * FROM pets")
    
    if (nrow(pets) == 0) {
      return(
        div(class = "empty-state-container",
            div(class = "empty-icon", "🐾"),
            h2("Your pack is empty"),
            p("No feeding schedules found. Add your first pet to start tracking their meals."),
            actionButton("add_pet", "+ Add Pet Sched", class = "btn-minimal")
        )
      )
    }
    
    lapply(1:nrow(pets), function(i) {
      sched_info <- dbGetQuery(pool, sprintf("SELECT is_active, feed_time FROM feeding_schedules WHERE pet_id = %d", pets$pet_id[i]))
      formatted_times <- sapply(sched_info$feed_time, function(t) format(as.POSIXct(paste("2026-01-01", t)), "%I:%M %p"))
      display_times <- paste(formatted_times, collapse = " & ")
      is_on <- if(nrow(sched_info) > 0 && !is.na(sched_info$is_active[1])) as.logical(sched_info$is_active[1]) else FALSE
      
      div(class = paste("pet-card-wrapper", if(is_on) "alarm-active" else "alarm-inactive"), 
          id = paste0("card_", pets$pet_id[i]),
          style = "position: relative; margin-bottom: 12px;",
          
          tags$div(
            class = "pet-card-body",
            onclick = sprintf("Shiny.setInputValue('editPetAlarm', %d, {priority: 'event'})", pets$pet_id[i]),
            
            div(style = "display: flex; justify-content: space-between; align-items: center;",
                div(
                  h4(pets$name[i], style="color:white; margin:0; font-weight:700; text-align:left"),
                  div(class = "feed-time-text",
                      style = "margin-top: 5px; text-align:left", 
                      ifelse(display_times == "", "Not set", display_times)
                  )
                ),
                
                div(class = "alarm-toggle", style = "display: flex; align-items: center;",
                    onclick = "event.stopPropagation();", 
                    tags$input(type = "checkbox", id = paste0("tog_", pets$pet_id[i]), 
                               checked = if(is_on) "checked" else NULL, 
                               onchange = sprintf("
                             updateCardStyle(%d, this.checked);
                             Shiny.setInputValue('toggleAlarm', {id: %d, status: this.checked}, {priority: 'event'});
                           ", pets$pet_id[i], pets$pet_id[i])),
                    tags$label(`for` = paste0("tog_", pets$pet_id[i]), class = "switch")
                )
            )
          )
      )
    })
  })
  
  observeEvent(input$cancelForm, {
    removeClass("dropdownModal", "show")
    removeClass("dropdownOverlay", "show")
  })
}

shinyApp(ui, server)
