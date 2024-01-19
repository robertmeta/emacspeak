;;; emacspeak-keymap.el --- Setup   keybindings -*- lexical-binding: t; -*-
;;
;; $Author: tv.raman.tv $
;; Description:  Module for setting up emacspeak keybindings
;; Keywords: Emacspeak
;;;   LCD Archive entry:

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;; A speech interface to Emacs |
;;
;;  $Revision: 4544 $ |
;; Location https://github.com/tvraman/emacspeak
;;

;;;   Copyright:

;; Copyright (C) 1995 -- 2024, T. V. Raman
;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;; All Rights Reserved.
;;
;; This file is not part of GNU Emacs, but the same permissions apply.
;;
;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This module defines the emacspeak keybindings.
;; Note that the <fn> key found on laptops is denoted <XF86WakeUp>

;;; Code:

;;;  requires

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(eval-when-compile (require 'cl-lib))
(cl-declaim  (optimize  (safety 0) (speed 3)))
(eval-when-compile (require 'subr-x))

;;;  Custom Widget Types:

(defun emacspeak-keymap-command-p (s)
  "Test if `s' can to be bound to a key."
  (or (commandp s) (keymapp s)))

(defsubst emacspeak-keymap-update (keymap binding)
  "Update keymap with  binding."
  (define-key keymap  (kbd (cl-first binding)) (cl-second binding)))

(defsubst emacspeak-keymap-bindings-update (keymap bindings)
  "Update keymap with  list of bindings."
  (cl-loop
   for binding in bindings
   do
   (define-key keymap (kbd (cl-first binding)) (cl-second binding))))

(define-widget 'ems-interactive-command 'restricted-sexp
  "An interactive command  or keymap that can be bound to a key."
  :completions
  (apply-partially #'completion-table-with-predicate
                   obarray 'emacspeak-keymap-command-p 'strict)
  :prompt-value 'widget-field-prompt-value
  :prompt-internal 'widget-symbol-prompt-internal
  :prompt-match 'emacspeak-keymap-command-p
  :prompt-history 'widget-function-prompt-value-history
  :action 'widget-field-action
  :match-alternatives '(emacspeak-keymap-command-p)
  :validate (lambda (widget)
              (unless (emacspeak-keymap-command-p (widget-value widget))
                (widget-put widget :error
                            (format "Invalid interactive command : %S"
                                    (widget-value widget)))
                widget))
  :value 'ignore
  :tag "Interactive Command")

;;;   variables:

(defvar emacspeak-prefix (kbd "C-e")
  "Emacspeak Prefix key. ")

(defvar emacspeak-keymap nil
  "Primary emacspeak keymap. ")

(defvar emacspeak-dtk-submap nil
  "Submap used for TTS commands. ")

(defvar emacspeak-table-submap nil
  "Submap used for table  commands. ")

;;;    Binding keymap and submap

(define-prefix-command  'emacspeak-keymap)
(define-prefix-command   'emacspeak-dtk-submap)
(define-prefix-command  'emacspeak-table-submap-command
                        'emacspeak-table-submap)

(global-set-key emacspeak-prefix 'emacspeak-keymap)

;;; Special keys:
(global-set-key (kbd "<XF86WakeUp>")  'dtk-stop)
(global-set-key (kbd "<XF86AudioPlay>")  'emacspeak-silence)
(global-set-key (kbd "C-<f1>")  'amixer-volume-down)
(global-set-key (kbd "C-<f2>")  'amixer-volume-up)
(global-set-key (kbd "<XF86AudioLowerVolume>")  'amixer-volume-down)
(global-set-key (kbd "<XF86AudioRaiseVolume>") 'amixer-volume-up)

(define-key emacspeak-keymap "d"  'emacspeak-dtk-submap)
(define-key emacspeak-keymap (kbd "C-t")  'emacspeak-table-submap-command)

;;;   The Emacspeak key  bindings.

;; help map additions:

(cl-loop
 for binding in
 '(
   ("'" describe-text-properties)
   ("C-k" describe-keymap)
   ("," emacspeak-wizards-color-at-point)
   ("/" describe-face)
   ("=" emacspeak-wizards-swap-fg-and-bg)
   ("B" customize-browse)
   ("C-<tab>" emacs-index-search)
   ("C-e"   emacspeak-describe-emacspeak)
   ("C-j" finder-commentary)
   ("C-l" emacspeak-learn-emacs)
   ("C-m" man)
   ("C-r" info-display-manual)
   ("C-s" emacspeak-wizards-customize-saved)
   ("C-v" emacspeak-wizards-describe-voice)
   ("G" customize-group)
   ("M" emacspeak-speak-popup-messages)
   ("M-F" find-function-at-point)
   ("M-V" find-variable-at-point)
   ("M-f" find-function)
   ("M-k" find-function-on-key)
   ("M-m" describe-minor-mode-from-indicator)
   ("M-v" find-variable)
   ("N" emacspeak-view-notifications)
   ("SPC" customize-group)
   ("TAB" emacspeak-info-wizard)
   ("V" customize-variable)
   ("\"" emacspeak-wizards-list-voices)
   (";" describe-font)
   ("\\" emacspeak-wizards-color-diff-at-point)
   ("p" list-packages)
   (":" describe-help-keys)
   )
 do
 (emacspeak-keymap-update help-map binding))

;; emacspeak-keymap bindings:
(cl-loop
 for binding in
 '(
   ("!" emacspeak-speak-run-shell-command)
   ("#" emacspeak-gridtext)
   ("$" flyspell-mode)
   ("%" emacspeak-speak-current-percentage)
   ("&" emacspeak-wizards-shell-command-on-current-file)
   ("'" emacspeak-empv-play-file)
   ("(" amixer)
   (")" emacspeak-sounds-select-theme)
   ("," emacspeak-buffer-select)
   ("." emacspeak-buffer-select)
   ("/" emacspeak-websearch-dispatch)
   ("1" emacspeak-speak-this-window)
   ("2" emacspeak-speak-other-window)
   ("3" amixer-volume-adjust)
   ("4" amixer-volume-adjust)
   (";" emacspeak-multimedia)
   ("<XF86WakeUp>" emacspeak-speak-brief-time)
   ("<down>" emacspeak-read-next-line)
   ("<f11>" emacspeak-wizards-shell-toggle)
   ("<f1>" emacspeak-learn-emacs)
   ("<left>" emacspeak-speak-this-buffer-previous-display)
   ("<next>" end-of-buffer)
   ("<prior>" beginning-of-buffer)
   ("<right>" emacspeak-speak-this-buffer-next-display)
   ("<up>"  emacspeak-read-previous-line)
   ("=" emacspeak-speak-current-column)
   ("?" emacspeak-websearch-dispatch)
   ("@" emacspeak-speak-message-at-time)
   ("A" emacspeak-appt-repeat-announcement)
   ("B" emacspeak-speak-buffer-interactively)
   ("C" emacspeak-customize)
   ("C-'" emacspeak-pianobar)
   ("C-." emacspeak-speak-face-browse)
   ("C-/" emacspeak-speak-this-buffer-other-window-display)
   ("C-<left>" emacspeak-select-this-buffer-previous-display)
   ("C-<return>" emacspeak-speak-continuously)
   ("C-<right>" emacspeak-select-this-buffer-next-display)
   ("C-@" emacspeak-speak-current-mark)
   ("C-M-c" emacspeak-clipfile-copy)
   ("C-M-q" emacspeak-toggle-speak-messages)
   ("C-M-y" emacspeak-clipboard-paste)
   ("C-SPC" emacspeak-speak-current-mark)
   ("C-a" emacspeak-toggle-auditory-icons)
   ("C-b" emacspeak-bookshare)
   ("C-c" emacspeak-selective-display)
   ("C-d" emacspeak-toggle-show-point)
   ("C-e" move-end-of-line)
   ("C-f" emacspeak-find-dired)
   ("C-i" emacspeak-open-info)
   ("C-j" emacspeak-hide-speak-block-sans-prefix)
   ("C-k" browse-kill-ring)
   ("C-l" what-line)
   ("C-m"  emacspeak-websearch-google)
   ("C-o" emacspeak-ocr)
   ("C-q" emacspeak-toggle-inaudible-or-comint-autospeak)
   ("C-r" restart-emacs)
   ("C-s" tts-restart)
   ("C-u" emacspeak-feeds-browse)
   ("C-v" view-mode)
   ("C-w" emacspeak-speak-window-information)
   ("C-x" emacspeak-speak-header-line)
   ("L" emacspeak-speak-line-interactively)
   ("M" emacspeak-speak-minor-mode-line)
   ("M-%" emacspeak-goto-percent)
   ("M-;" emacspeak-eww-play-media-at-point)
   ("M-C-SPC" emacspeak-speak-spaces-at-point)
   ("M-SPC" emacspeak-speak-completions-if-available)
   ("M-b" emacspeak-speak-other-buffer)
   ("M-c" emacspeak-copy-current-file)
   ("M-d" emacspeak-pronounce-dispatch)
   ("M-e" emacspeak-speak-extent)
   ("M-h" emacspeak-speak-hostname)
   ("M-i" emacspeak-table-display-table-in-region)
   ("M-l" emacspeak-speak-overlay-properties)
   ("M-m" emacspeak-toggle-mail-alert)
   ("M-o" emacspeak-toggle-comint-output-monitor)
   ("M-p" emacspeak-show-property-at-point)
   ("M-s" emacspeak-symlink-current-file)
   ("M-t" emacspeak-describe-tapestry)
   ("M-u" emacspeak-feeds-add-feed)
   ("M-v" emacspeak-show-style-at-point)
   ("M-w" emacspeak-speak-which-function)
   ("N" emacspeak-view-emacspeak-news)
   ("P" emacspeak-speak-paragraph-interactively)
   ("R" emacspeak-speak-rectangle)
   ("SPC" emacspeak-speak-windowful)
   ("T" emacspeak-view-emacspeak-tips)
   ("V" emacspeak-speak-version)
   ("W" emacspeak-select-window-by-name)
   ("[" emacspeak-speak-paragraph)
   ("\"" emacspeak-empv-play-local)
   ("\\" emacspeak-toggle-speak-line-invert-filter)
   ("]" emacspeak-speak-page)
   ("^" emacspeak-filtertext)
   ("`"  emacspeak-speak-net-id)
   ("a" emacspeak-speak-message-again)
   ("b" emacspeak-speak-buffer)
   ("c" emacspeak-speak-char)
   ("e" move-end-of-line)
   ("f" emacspeak-speak-buffer-filename)
   ("g" emacspeak-epub)
   ("h" emacspeak-speak-help)
   ("i" emacspeak-speak-rest-of-buffer)
   ("j" emacspeak-hide-or-expose-block)
   ("k" emacspeak-speak-current-kill)
   ("l" emacspeak-speak-line)
   ("m" emacspeak-speak-mode-line)
   ("n" emacspeak-buffer-select)
   ("o" delete-blank-lines)
   ("p" emacspeak-buffer-select)
   ("r" emacspeak-speak-region)
   ("s" dtk-stop)
   ("t" emacspeak-speak-time)
   ("u" emacspeak-url-template-fetch)
   ("w" emacspeak-speak-word)
   ("|" emacspeak-speak-line-set-column-filter)
   )
 do
 (emacspeak-keymap-update emacspeak-keymap binding))

(cl-loop
 for binding in
 '(
   ("=" dtk-rate-adjust)
   ("+" dtk-rate-adjust)
   ("-" dtk-rate-adjust)
   ("," dtk-toggle-punctuation-mode)
   ("." dtk-notify-stop)
   ("C-c" dtk-cloud)
   ("C-d" dectalk)
   ("C-e" espeak)
   ("C-s" dectalk-soft)
   ("C-j" dtk-set-chunk-separator-syntax)
   ("C-n" dtk-notify-initialize)
   ("C-o" outloud)
   ("C-v" global-voice-lock-mode)
   ("d" dtk-select-server)
   ("L" dtk-local-server)
   ("N" dtk-set-next-language)
   ("P" dtk-set-previous-language)
   ("R" dtk-reset-state)
   ("S" dtk-set-language)
   ("SPC" dtk-toggle-splitting-on-white-space)
   ("V" tts-speak-version)
   ("a" dtk-add-cleanup-pattern)
   ("c" dtk-toggle-caps)
   ("f" dtk-set-character-scale)
   ("i" emacspeak-toggle-audio-indentation)
   ("k" emacspeak-toggle-character-echo)
   ("l" emacspeak-toggle-line-echo)
   ("n" dtk-toggle-speak-nonprinting-chars)
   ("o" dtk-toggle-strip-octals)
   ("p" dtk-set-punctuations)
   ("q" dtk-toggle-quiet)
   ("r" dtk-set-rate)
   ("s" dtk-toggle-split-caps)
   ("v" voice-lock-mode)
   ("w" emacspeak-toggle-word-echo)
   ("z" emacspeak-zap-tts)
   )
 do
 (emacspeak-keymap-update emacspeak-dtk-submap binding))

(dotimes (i 10)
  (define-key emacspeak-dtk-submap
              (format "%s" i)   'dtk-set-predefined-speech-rate))

(cl-loop
 for binding in
 '(
   ("f" emacspeak-table-find-file)
   ("," emacspeak-table-find-csv-file)
   )
 do
 (emacspeak-keymap-update emacspeak-table-submap binding))

;; Put these in the global map:
(global-set-key [(shift left)] 'emacspeak-skip-space-backward)
(global-set-key [(shift right)] 'emacspeak-skip-space-forwar)
(global-set-key [(shift up)] 'emacspeak-skip-blank-lines-backward)
(global-set-key [(shift down)] 'emacspeak-skip-blank-lines-forward)
(global-set-key [27 up]  'emacspeak-owindow-previous-line)
(global-set-key  [27 down]  'emacspeak-owindow-next-line)
(global-set-key  [27 prior]  'emacspeak-owindow-scroll-down)
(global-set-key  [27 next]  'emacspeak-owindow-scroll-up)
(define-key esc-map "\M-:" 'emacspeak-wizards-show-eval-result)

;;;  emacspeak under X windows

;; Get hyper, alt, super, and multi:
(global-set-key (kbd "C-,") 'emacspeak-alt-keymap)
(global-set-key  (kbd "C-.") 'emacspeak-super-keymap)
(global-set-key  (kbd "C-;") 'emacspeak-hyper-keymap)
(global-set-key  (kbd "C-'") 'emacspeak-multi-keymap)

;; Our very own silence key on the console
(global-set-key '[silence] 'emacspeak-silence)

;;;  Create personal c-e v map

(defvar  emacspeak-v-keymap nil
  "Emacspeak v keymap")

(define-prefix-command 'emacspeak-v-keymap)

(defcustom emacspeak-v-keys
  '(
    ("v" view-register)
    )
  "Key bindings for use with C-e v. "
  :group 'emacspeak
  :type
  '(repeat
    :tag "Emacspeak V Keymap"
    (list
     :tag "Key Binding"
     (key-sequence :tag "Key")
     (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (emacspeak-keymap-bindings-update emacspeak-v-keymap val)
      (set-default sym
                   (sort
                    val
                    #'(lambda (a b) (string-lessp (car a) (car b)))))))

;;;  Create a personal keymap for c-e x

;; Adding keys using custom:
(defvar  emacspeak-x-keymap nil
  "Emacspeak personal keymap")

(define-prefix-command 'emacspeak-x-keymap)

(defcustom emacspeak-x-keys
  '(
    ("," emacspeak-wizards-shell-directory-set)
    ("." emacspeak-wizards-shell-directory-reset)
    ("0" emacspeak-wizards-shell-by-key)
    ("1" emacspeak-wizards-shell-by-key)
    ("2" emacspeak-wizards-shell-by-key)
    ("3" emacspeak-wizards-shell-by-key)
    ("4" emacspeak-wizards-shell-by-key )
    ("5" emacspeak-wizards-shell-by-key)
                                        ;("6" emacspeak-speak-message-at-time)
    ("7" emacspeak-wizards-shell-command-on-current-file)
    ("8" calc)
                                        ;("9" emacspeak-wizards-shell-by-key)
    ("=" emacspeak-wizards-find-longest-line-in-region)
    ("M-c" emacspeak-wizards-colors)
    (":" emacspeak-m-player-loop)
    (";" emacspeak-m-player-shuffle)
    ("b" battery)
    ("C-c" emacspeak-wizards-color-wheel)
    ("d" emacspeak-speak-load-directory-settings)
    ("e" emacspeak-we-xsl-map)
    ("f" emacspeak-wizards-remote-frame)
    ("h" emacspeak-wizards-how-many-matches)
    ("i" ibuffer)
    ("m" mspools-show)
    ("o" emacspeak-wizards-occur-header-lines)
    ("p" paradox-list-packages)
    ("t" emacspeak-speak-telephone-directory)
    ("u" emacspeak-wizards-units)
    ("v" emacspeak-wizards-vc-viewer)
    ("w" emacspeak-wizards-noaa-weather)
    ("x" exchange-point-and-mark)
    ("|" emacspeak-wizards-squeeze-blanks)
    ("" desktop-clear)
    )
  "Key bindings for  C-e x. "
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak x Keymap"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (emacspeak-keymap-bindings-update emacspeak-x-keymap val)
      (set-default
       sym
       (sort
        val
        #'(lambda (a b) (string-lessp (car a) (car b)))))))

(define-key emacspeak-keymap "v" 'emacspeak-v-keymap)
(define-key  emacspeak-keymap "x" 'emacspeak-x-keymap)
(define-key  emacspeak-keymap "y" 'emacspeak-y-keymap)

;;;  Create personal y map

(defvar  emacspeak-y-keymap nil
  "Emacspeak y keymap")

(define-prefix-command 'emacspeak-y-keymap)

(defcustom emacspeak-y-keys
  '(
    ("p" emacspeak-pianobar)
    ("a" emacspeak-xslt-view-atom-file)
    ("r" emacspeak-xslt-view-rss-file)
    ("x" emacspeak-xslt-view-file)
    ("y" emacspeak-empv-play-url)
    )
  "Key bindings for use with C-e y. "
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak Personal-Y Keymap"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (emacspeak-keymap-bindings-update emacspeak-y-keymap val)
      (set-default sym
                   (sort
                    val
                    #'(lambda (a b) (string-lessp (car a) (car b)))))))

;;;  Create a C-z keymap that is customizable

;; 2020: Suspending emacs with C-z is something I've not done in 30
;; years.
;; Turn it into a useful prefix key.

(defvar  emacspeak-z-keymap nil
  "Emacspeak ctl-z keymap")

(define-prefix-command 'emacspeak-z-keymap)
(global-set-key (kbd "C-z") 'emacspeak-z-keymap)
(defcustom emacspeak-ctl-z-keys
  '(
    ("SPC" flyspell-mode)
    ("b" emacspeak-wizards-view-buffers-filtered-by-this-mode)
    ("c" calibredb)
    ("d" magit-dispatch)
    ("e" emacspeak-wizards-eww-buffer-list)
    ("f" magit-file-dispatch)
    ("l" emacspeak-m-player-locate-media)
    ("n" emacspeak-wizards-buffer-select)
    ("p" emacspeak-wizards-buffer-select)
    ("r" restart-emacs)
    ("s" magit-status)
    ("z" suspend-frame)
    )
  "CTL-z keymap."
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak C-Z  Keys"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (emacspeak-keymap-bindings-update emacspeak-z-keymap val)
      (set-default sym
                   (sort
                    val
                    #'(lambda (a b) (string-lessp (car a) (car b)))))))

(define-key emacspeak-keymap  "z" 'emacspeak-z-keymap)

;;;  Create a hyper keymap that users can put personal commands

(defvar  emacspeak-hyper-keymap nil
  "Emacspeak hyper keymap")

(define-prefix-command 'emacspeak-hyper-keymap)

(defcustom emacspeak-hyper-keys
  '(
    ("C-;" emacspeak-amark-bookshelf)
    ("C-a" ansi-term)
    ("C-b" eww-list-bookmarks)
    ("C-d" dictionary-search)
    ("C-e" eshell)
    ("C-j" journalctl)
    ("C-l" emacspeak-librivox)
    ("C-t" emacspeak-wizards-tramp-open-location)
    ("DEL" emacspeak-wizards-snarf-sexp)
    ("TAB" hippie-expand)
    ("a" emacspeak-amark-browse)
    ("b" emacspeak-wizards-bbc-sounds)
    ("c" browse-url-chrome)
    ("d" magit-dispatch)
    ("f" magit-file-dispatch)
    ("g" gnus)
    ("h" emacspeak-m-player-from-history)
    ("i" ibuffer)
    ("j" emacspeak-zoxide)
    ("l" emacspeak-m-player-locate-media)
    ("m" vm)
    ("o" find-file)
    ("r" emacspeak-wizards-find-file-as-root)
    ("s" magit-status)
    ("u" list-unicode-display)
    ("w" emacspeak-wizards-noaa-weather)
    ("y" yas-expand)
    )
  "Hyper-Key bindings. "
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak Hyper Keys"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (emacspeak-keymap-bindings-update emacspeak-hyper-keymap val)
      (set-default sym
                   (sort
                    val
                    #'(lambda (a b) (string-lessp (car a) (car b)))))))
(global-set-key "\C-x@h" 'emacspeak-hyper-keymap)

;;;  Create a super keymap that users can put personal commands

(defvar  emacspeak-super-keymap nil
  "Emacspeak super keymap")

(define-prefix-command 'emacspeak-super-keymap)

(defcustom emacspeak-super-keys
  '(
    ("SPC"  scratch-buffer)
    ("." emacspeak-wizards-shell-directory-reset)
    ("C-n" emacspeak-wizards-google-headlines)
    ("R" emacspeak-webspace-feed-reader)
    ("b" eww-list-buffers)
    ("c" calculator)
    ("d" emacspeak-dired-downloads)
    ("e" elfeed)
    ("f" browse-url-firefox)
    ("g" emacspeak-google-tts)
    ("h" emacspeak-org-capture-link)
    ("l" emacspeak-wizards-locate-content)
    ("m" emacspeak-wizards-view-buffers-filtered-by-this-mode)
    ("n" emacspeak-wizards-google-news)
    ("p" proced)
    ("r" soundscape-restart)
    ("s" soundscape)
    ("t" soundscape-toggle)
    ("u" soundscape-update-mood)
    ("y" empv-youtube-tabulated))
  "Super key bindings. "
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak Super Keymap"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (emacspeak-keymap-bindings-update emacspeak-super-keymap  val)
      (set-default sym
                   (sort
                    val
                    #'(lambda (a b) (string-lessp (car a) (car b)))))))

(global-set-key "\C-x@s" 'emacspeak-super-keymap)

;;;  Create an  alt keymap that users can put personal commands

(defvar  emacspeak-alt-keymap nil "Emacspeak alt keymap")

(define-prefix-command 'emacspeak-alt-keymap)

(defcustom emacspeak-alt-keys
  '(
    ("," eldoc)
    ("a" emacspeak-feeds-atom-display)
    ("b" sox-binaural)
    ("c" gptel)
    ("d" deadgrep)
    ("e" eww)
    ("f" ffip)
    ("g" rg)
    ("l" ellama-chat)
    ("o" emacspeak-feeds-opml-display)
    ("p" emacspeak-wizards-pdf-open)
    ("q" emacspeak-wizards-quotes)
    ("r" emacspeak-feeds-rss-display)
    ("s" emacspeak-wizards-tune-in-radio-search)
    ("t" emacspeak-wizards-tune-in-radio-browse)
    ("u" emacspeak-m-player-url)
    ("v" visual-line-mode)
    ("w" define-word)
    ("SPC" emacspeak-eww-smart-tabs)
    )
  "Alt key bindings. "
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak Alt Keymap"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set #'(lambda (sym val)
           (emacspeak-keymap-bindings-update emacspeak-alt-keymap val)
           (set-default sym
                        (sort
                         val
                         #'(lambda (a b) (string-lessp (car a) (car b)))))))

(global-set-key "\C-x@a" 'emacspeak-alt-keymap)

;;;  Create a multi keymap that users can put personal commands

(defvar  emacspeak-multi-keymap nil "Emacspeak multi keymap")

(define-prefix-command 'emacspeak-multi-keymap)

(defcustom emacspeak-multi-keys
  '(
    ("C-'" empv-exit)
    ("'" emacspeak-pianobar)
    ("d" sdcv-search-input)
    ("e" eat)
    ("f" ffap)
    ("l" locate)
    ("o" org-mode)
    ("m" notmuch-search)
    ("y" emacspeak-google-yt-feed))
  "Multi key bindings. "
  :group 'emacspeak
  :type '(repeat
          :tag "Emacspeak Multi Keymap"
          (list
           :tag "Key Binding"
           (key-sequence :tag "Key")
           (ems-interactive-command :tag "Command")))
  :set #'(lambda (sym val)
           (emacspeak-keymap-bindings-update emacspeak-multi-keymap val)
           (set-default sym
                        (sort
                         val
                         #'(lambda (a b) (string-lessp (car a) (car b)))))))

;;; Windows Key As One More Map
(defcustom emacspeak-windows-keys nil
  "Key bindings on the windows  key. "
  :group 'emacspeak
  :type
  '(repeat
    :tag "Emacspeak windows Keys"
    (list
     :tag "Key Binding"
     (character :tag "Key")
     (ems-interactive-command :tag "Command")))
  :set
  #'(lambda (sym val)
      (when val
        (cl-loop
         for binding in val do
         (global-set-key
          (vector
           (event-apply-modifier (cl-first binding) 'super 23 "s-"))
          (cl-second binding))))
      (set-default
       sym
       (sort
        val
        #'(lambda (a b) (< (car a) (car b)))))))

;;;  Helper: recover end-of-line

(defun emacspeak-keymap-recover-eol ()
  "Recover EOL ."
  (cl-declare (special emacspeak-prefix))
  (global-set-key (concat emacspeak-prefix "e") 'move-end-of-line)
  (global-set-key (concat emacspeak-prefix emacspeak-prefix) 'move-end-of-line))
(add-hook 'after-change-major-mode-hook  'emacspeak-keymap-recover-eol)

;;;  Global Bindings From Other Modules:
(global-set-key (kbd "C-x r C-e") 'emacspeak-eww-marks-browse)
(global-set-key (kbd "C-x r e") 'emacspeak-eww-open-mark)

(provide 'emacspeak-keymap)
 

