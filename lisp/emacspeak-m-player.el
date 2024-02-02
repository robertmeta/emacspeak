;;; emacspeak-m-player.el --- Media Player -*- lexical-binding: t; -*-
;;
;; $Author: tv.raman.tv $
;; Description: Controlling mplayer from emacs
;; Keywords: Emacspeak, m-player streaming media
;;;   LCD Archive entry:

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;; A speech interface to Emacs |
;;
;;  $Revision: 4532 $ |
;; Location https://github.com/tvraman/emacspeak
;;

;;;   Copyright:

;; Copyright (c) 1995 -- 2024, T. V. Raman
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

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

:

;;; Commentary:

;; Defines an Emacspeak front-end for interacting with @code{mplayer}.
;; Program @code{mplayer}  is a versatile media player capable of playing many
;; streaming media formats.
;; This module provides complete access to all @code{mplayer} functionality
;; from a convenient Emacs interface.
;;
;; @subsection Usage
;;
;; The main entry-point is command @code{emacspeak-multimedia} bound
;; to @kbd{C-e ;}.  This prompts for and launches the desired media
;; stream.  Once a stream is playing, you can control it with
;; single-letter keystrokes in the @code{*M-Player*} buffer.
;; Alternatively, you can switch away from that buffer to do real
;; work, And invoke @code{m-player} commands by first pressing
;; prefix-key @kbd{C-e ;}.  If your Emacs supports @code{repeat-mode},
;; --- @xref{repeating, , , emacs} you can avoid the need to
;; repeatedly press the prefix-key @code{C-e ;} each time; with
;; @code{repeat-mode} active, you only need to press the prefix
;; @code{C-e ;} the first time; subsequent invocations can happen via
;; single-letter presses as long as they are performed in a sequence.
;; As an example, pressing @kbd{v} in the @code{*M-Player*} buffer
;; prompts for and sets the volume; When not in the @code{*M-Player*}
;; buffer, you can achieve the same by pressing @kbd{C-e ; v}.  Press
;; @kbd{C-h b} in the @code{*M-Player*} buffer to list @code{m-player}
;; keybindings.
;;
;;; Code:

;;;   Required modules

(eval-when-compile (require 'cl-lib))
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'dired)
(require 'emacspeak-dired)
(require 'ladspa)
(require 'emacspeak-amark)

(declare-function emacspeak-xslt-get "emacspeak-xslt" (style))

;;;  Stream Metadata:

(cl-defstruct ems--media-data
  title artist album info
  year comment track genre)

(defvar-local ems--media-data nil
  "Instance of stream metadata for this buffer.")

(defun emacspeak-m-player-show-data ()
  "Display metadata after refreshing it if needed."
  (interactive)
  (let ((data (emacspeak-m-player-data-refresh)))
    (with-output-to-temp-buffer "M Player Metadata"
      (cl-loop
       for f in
       (cl-rest
        (mapcar #'car (cl-struct-slot-info 'ems--media-data)))
       do
       (when (cl-struct-slot-value 'ems--media-data f data)
         (princ
          (format
           "%s:\t%s\n"
           f
           (cl-struct-slot-value 'ems--media-data f data))))))
    (message "Displayed metadata in other window.")
    (emacspeak-auditory-icon 'task-done)))

;;;  define a derived mode for m-player interaction
(define-derived-mode emacspeak-m-player-mode special-mode
  "M-Player Interaction"
  "Major mode for m-player interaction. \n\n
\\{emacspeak-m-player-mode-map}"
  (progn
    (setq ems--media-data (make-ems--media-data)
          buffer-undo-list t
          buffer-read-only nil)))

(defconst  emacspeak-media-shortcuts-directory
  (expand-file-name "media/radio/" emacspeak-directory)
  "Directory where we organize   and media shortcuts. ")

(defvar emacspeak-m-player-process nil
  "Process handle to m-player.")

(defun ems--mp-send (command)
  "Dispatch command to m-player."
  (cl-declare (special emacspeak-m-player-process))
  (with-current-buffer (process-buffer emacspeak-m-player-process)
    (erase-buffer)
    (process-send-string
     emacspeak-m-player-process
     (format "pausing_keep %s\n" command))
    (accept-process-output emacspeak-m-player-process 0.1)
    (unless (zerop (buffer-size))
      (buffer-substring-no-properties (point-min) (1-  (point-max))))))

(defvar-local  emacspeak-m-player-directory nil
  "Records current directory of media being played.
This is set to nil when playing Internet  streams.")

(defsubst ems--seconds-string-to-duration (sec)
  "Return seconds formatted as time if valid, otherwise return as is."
  (let ((v (car  (read-from-string sec))))
    (cond
     ((and (numberp v) (not (cl-minusp v)))
      (format-seconds "%.2h:%.2m:%.2s%z" v))
     (t sec))))

(defsubst ems--duration-to-seconds (d)
  "Convert hh:mm:ss to seconds."
  (let*
      ((sign (string-match "^-" d))
       (v
        (mapcar
         #'car
         (mapcar
          #'read-from-string
          (split-string (if sign (substring d 1) d) ":")))))
    (* (if sign -1 1)
       (+
        (* 3600 (cl-first v))
        (* 60 (cl-second v))
        (cl-third v)))))

(defun emacspeak-m-player-mode-line ()
  "Mode-line for M-Player buffers."
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (dtk-notify-speak
   (cond
    ((eq 'run (process-status emacspeak-m-player-process))
     (let ((info (emacspeak-m-player-get-position)))
       (when info
         (concat
          (propertize "Position:  " 'pause 90)
          (ems--seconds-string-to-duration (cl-first info))
          (propertize " of " 'personality voice-smoothen-extra)
          (ems--seconds-string-to-duration (cl-third info))
          (propertize " in " 'personality voice-smoothen-extra)
          (cl-second info)))))
    (t (format "Process MPlayer not running.")))))

;;; Dynamic playlist:

;; Dynamic playlists are one-shot, and managed directly by emacspeak,
;; i.e. no playlist file.

(defvar emacspeak-media-dynamic-playlist  nil
  "Dynamic --- lists files in the playlist.
Reset immediately after being used.")

;;;###autoload
(defun emacspeak-m-player-add-dynamic (file)
  "Add file to the current  dynamic playlist."
  (interactive
   (list
    (or
     (dired-get-filename  nil t)
     (read-file-name "MP3 File:"))))
  (cl-declare (special emacspeak-media-dynamic-playlist))
  (cond
   ((file-directory-p file)
    (cl-loop
     for f in
     (directory-files-recursively file  "\\.mp3\\'") do
     (cl-pushnew f emacspeak-media-dynamic-playlist))
    (dtk-speak-and-echo
     (format "Added files from directory %s" (file-name-base file))))
   ((string-match "\\.mp3$" file)
    (cl-pushnew file emacspeak-media-dynamic-playlist)
    (dtk-speak-and-echo
     (format
      "Added %s with duration %s to dynamic playlist."
      (file-name-base file)
      (shell-command-to-string (format "soxi -d '%s'" file)))))
   (t (message "No MP3 here.")))
  (forward-line 1)
  (emacspeak-dired-speak-line))

(defun ems--dynamic-playlist-duration ()
  "Return duration of dynamic playlist."
  (cl-declare (special emacspeak-media-dynamic-playlist))
  (cl-assert emacspeak-media-dynamic-playlist t "No dynamic playlist")
  (ems-with-messages-silenced
   (let* ((result nil)
          (buff  " *soxi*")
          (proc
           (apply
            #'start-process
            "soxi" buff
            "soxi" "-Td"
            emacspeak-media-dynamic-playlist)))
     (accept-process-output proc 0 100)
     (with-current-buffer buff
       (goto-char (point-min))
       (setq result
             (buffer-substring-no-properties
              (line-beginning-position) (line-end-position))))
     result)))

;;;  emacspeak-m-player

(defgroup emacspeak-m-player nil
  "Emacspeak media player."
  :group 'emacspeak)

;;;###autoload
(defcustom emacspeak-mplayer
  (executable-find "mplayer")
  "Media player program."
  :type 'string
  :group 'emacspeak-m-player)

(defvar emacspeak-m-player-openal-options
  '("-ao" "openal")
  "Options to use openal  --- this gives us hrtf etc..")

(defvar emacspeak-m-player-default-options
  (list
   "-msglevel"          ; reduce chattiness  while preserving metadata
   (mapconcat
    #'identity
    '("all=4"
      "header=0" "vo=0" "ao=0"
      "decaudio=0" "decvideo=0" "open=0"
      "network=0" "statusline=0" "cplayer=0"
      "seek=0"
      ) ":")
   "-slave"  "-softvol" "-softvol-max" "300" "-quiet" "-use-filedir-conf")
  "Default options for MPlayer.")

(defvar emacspeak-m-player-options
  (copy-sequence emacspeak-m-player-default-options)
  "Options passed to mplayer.")

(defcustom emacspeak-m-player-custom-filters
  nil
  "Additional filters to apply to streams."
  :type
  '(repeat
    (string :tag "filter"))
  :group 'emacspeak-m-player)

;;;###autoload
(defcustom emacspeak-media-location-bindings  nil
  "Map  keys  to launch MPlayer on a  directory."
  :group 'emacspeak-m-player
  :group 'emacspeak-media
  :type
  '(repeat
    :tag "Media Locations"
    (list
     (string :tag "Key")
     (directory :tag "Directory")))
  :set
  #'(lambda (sym val)
      (mapc
       #'(lambda (binding)
           (let ((key (cl-first binding))
                 (directory (cl-second binding)))
             (emacspeak-m-player-bind-hotkey directory (kbd key))))
       val)
      (set-default sym val)))

(defvar emacspeak-media-directory-regexp
  (regexp-opt '("mp3" "audio" ))
  "Pattern matching locations where we store media.")

;;;###autoload
(defun emacspeak-multimedia  ()
  "Start or control Emacspeak multimedia player.
Controls media playback when already playing.

\\{emacspeak-m-player-mode-map}"
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (cond
   ((and emacspeak-m-player-process
         (eq 'run (process-status emacspeak-m-player-process))
         (buffer-live-p (process-buffer emacspeak-m-player-process)))
    (with-current-buffer (process-buffer emacspeak-m-player-process)
      (call-interactively #'emacspeak-m-player-command)))
   (t
    (call-interactively #'emacspeak-m-player))))

(defun emacspeak-m-player-pop-to-player ()
  "Pop to m-player buffer."
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (unless (process-live-p emacspeak-m-player-process)
    (emacspeak-multimedia))
  (funcall-interactively
   #'switch-to-buffer (process-buffer emacspeak-m-player-process)))

(defun emacspeak-m-player-command (key)
  "Invoke MPlayer commands."
  (interactive (list (read-key-sequence "Key: ")))
  (call-interactively
   (when emacspeak-m-player-process
     (or
      (lookup-key emacspeak-m-player-mode-map key)
      'undefined))))

(defsubst emacspeak-m-player-playlist-p (resource)
  "Check if specified resource matches a playlist type."
  (cl-declare (special emacspeak-playlist-pattern))
  (string-match emacspeak-playlist-pattern resource))

(defun emacspeak-m-player-bind-hotkey (directory key)
  "Binds key to invoke m-player  on specified directory."
  (interactive
   (list
    (read-directory-name"Media Directory: ")
    (read-key-sequence "Key: ")))
  (let
      ((command
        (eval
         `(defun
              ,(intern
                (format "emacspeak-media-%s"
                        (file-name-base (directory-file-name directory))))
              (&optional prefix)
            ,(format "Launch media from directory %s. Prefix arg
plays result as a directory." directory)
            (interactive)
            (cl-declare  (special
                          default-directory emacspeak-m-player-directory))
            (let ((default-directory ,directory))
              (setq emacspeak-m-player-directory ,directory)
              (emacspeak-m-player-hotkey ,directory))))))
    (global-set-key key command)
    (put command 'repeat-map 'emacspeak-m-player-mode-map)))

(defvar emacspeak-m-player-hotkey-p nil
  "Flag set by hotkeys. Let-binding this causes default-directory
 to be ignored when guessing directory.")

(defun emacspeak-m-player-hotkey (directory)
  "Launch MPlayer on   `directory'."
  (cl-declare (special ido-case-fold))
  (let ((ido-case-fold t)
        (emacspeak-m-player-hotkey-p t)
        (emacspeak-media-shortcuts-directory (expand-file-name directory)))
    (call-interactively #'emacspeak-multimedia)
    (emacspeak-auditory-icon 'select-object)))

(defun emacspeak-media-guess-directory ()
  "Guess default directory.
If default directory matches emacspeak-media-directory-regexp,
use it.  If default directory contains media files, then use it.
Otherwise use emacspeak-media-directory as the fallback."
  (cl-declare (special emacspeak-media-directory-regexp
                       emacspeak-m-player-hotkey-p))
  (let ((case-fold-search t))
    (cond
     ((or (eq major-mode 'dired-mode) (eq major-mode 'locate-mode)) nil)
     (emacspeak-m-player-hotkey-p   emacspeak-media-shortcuts-directory)
     ((or                               ;  dir  contains media:
       (string-match emacspeak-media-directory-regexp default-directory)
       (directory-files default-directory   nil emacspeak-media-extensions))
      default-directory)
     (t   emacspeak-media-shortcuts-directory))))

;;;###autoload
(defun emacspeak-m-player-url (url &optional playlist-p)
  "Call emacspeak-m-player on  URL.
URL fragment specifies optional start position."
  (interactive
   (list (car (browse-url-interactive-arg "Media URL: "))))
  (cl-declare (special emacspeak-m-player-options))
  (ems-with-messages-silenced
   (cl-multiple-value-bind
       (link offset ) (split-string url "#")
     (cond
      (offset
       (let ((emacspeak-m-player-options
              (append emacspeak-m-player-options (list "-ss" offset))))
         (emacspeak-m-player link playlist-p)))
      (t (emacspeak-m-player link playlist-p))))))

(defsubst emacspeak-m-player-directory-files (directory)
  "Return media files in directory. "
  (cl-declare (special emacspeak-media-extensions))
  (let ((case-fold-search t))
    (directory-files-recursively directory emacspeak-media-extensions)))

(defvar-local emacspeak-m-player-url-p nil
  "Records if  playing a URL")

(defvar-local emacspeak-m-player-url nil
  "Records   currently playing URL")

(defvar-local emacspeak-m-player-resource nil
  "Records   currently playing resource")

(defun emacspeak-media-local-resource (prefix)
  "Read local filename starting from default-directory or
  emacspeak-m-player-directory using completion over all
subfiles.  Interactive prefix arg causes it to read a directory
rather than completing over all subfiles."
  (cl-declare (special default-directory))
  (let ((completion-ignore-case t)
        (case-fold-search t))
    (cond
     (prefix
      (setq current-prefix-arg nil)
      (read-directory-name "Media:" emacspeak-m-player-directory))
     (t
      (completing-read
       "Media: "
       (directory-files-recursively
        default-directory emacspeak-media-extensions))))))

(defun emacspeak-media-read-resource (&optional prefix)
  "Read resource from minibuffer.
If a dynamic playlist exists, just use it."
  (cl-declare (special emacspeak-media-dynamic-playlist
                       emacspeak-m-player-hotkey-p))
  (unless emacspeak-media-dynamic-playlist
    (cond
     (emacspeak-m-player-hotkey-p (emacspeak-media-local-resource prefix))
     (t
      (let ((completion-ignore-case t)
            (read-file-name-completion-ignore-case t)
            (filename
             (when (memq major-mode '(dired-mode locate-mode))
               (dired-get-filename 'local 'no-error)))
            (dir (emacspeak-media-guess-directory)))
        (expand-file-name  (read-file-name "Media: " dir filename t)))))))

(defun emacspeak-m-player-data-refresh ()
  "Populate metadata fields from current  stream."
  (cl-declare (special ems--media-data))
  (with-current-buffer (process-buffer emacspeak-m-player-process)
    (cl-loop
     for  f in
     '(title artist album year comment track genre)
     do
     (aset ems--media-data
           (cl-struct-slot-offset 'ems--media-data f)
           (cl-second
            (split-string
             (emacspeak-m-player-slave-command (format "get_meta_%s" f))
             "="))))
    ems--media-data))

(defvar emacspeak-m-player-cue-info nil
  "Set to T if  ICY info cued automatically.")

(defun ems--mp-filter (process output)
  "Filter function to captures metadata.
 Cleanup ANSI escape sequences."
  (cl-declare (special emacspeak-m-player-cue-info
                       ansi-color-control-seq-regexp))
  (when (process-live-p process)
    (with-current-buffer (process-buffer process)
      (when (and ems--media-data
                 (ems--media-data-p ems--media-data)
                 (string-match "ICY Info:" output))
        (setf
         (ems--media-data-info ems--media-data)
         (format "%s" output))
        (when emacspeak-m-player-cue-info
          (emacspeak-auditory-icon 'progress)
          (emacspeak-m-player-stream-info)))
      (goto-char (process-mark process))
      (let ((start (point)))
        (insert output)
        (save-excursion
          (goto-char start)
          (while
              (re-search-forward ansi-color-control-seq-regexp
                                 (point-max) 'no-error)
            (delete-region (match-beginning 0) (match-end 0))))))))

(defun emacspeak-m-player-amark-save ()
  "Save amarks."
  (interactive)
  (cl-declare (special emacspeak-m-player-process
                       emacspeak-m-player-directory))
  (when
      (and  emacspeak-m-player-directory
            (process-live-p emacspeak-m-player-process))
    (with-current-buffer
        (process-buffer emacspeak-m-player-process)
      (emacspeak-amark-save))))

(defvar emacspeak-m-player-paused nil
  "Pause/unpased state of player.")

;;;###autoload
(defun emacspeak-m-player (resource &optional play-list)
  "Play  resource, or play dynamic playlist if set.  Optional prefix argument
play-list interprets resource as a play-list.  Second interactive
prefix arg adds option -allow-dangerous-playlist-parsing to mplayer.
See command \\[emacspeak-m-player-add-dynamic] for adding to the
dynamic playlist. "
  (interactive
   (list
    (emacspeak-media-read-resource current-prefix-arg)
    current-prefix-arg))
  (cl-declare (special
               emacspeak-m-player-paused emacspeak-m-player-resource
               emacspeak-media-dynamic-playlist
               emacspeak-m-player-hotkey-p
               emacspeak-m-player-directory
               emacspeak-media-directory-regexp
               emacspeak-media-shortcuts-directory emacspeak-m-player-process
               emacspeak-mplayer emacspeak-m-player-options
               emacspeak-m-player-url emacspeak-m-player-url-p
               emacspeak-m-player-custom-filters))
  (when
      (and emacspeak-m-player-process
           (eq 'run (process-status emacspeak-m-player-process))
           (y-or-n-p "Stop "))
    (emacspeak-m-player-quit)
    (setq emacspeak-m-player-process nil))
  (let ((buffer (get-buffer-create "*M-Player*"))
        (process-connection-type nil)
        (playlist-p
         (and resource
              (or play-list (emacspeak-m-player-playlist-p resource))))
        (options (copy-sequence emacspeak-m-player-options))
        (file-list  (reverse emacspeak-media-dynamic-playlist))
        (duration
         (when emacspeak-media-dynamic-playlist
           (ems--dynamic-playlist-duration))))
    (when emacspeak-m-player-custom-filters
      (cl-pushnew
       (mapconcat #'identity emacspeak-m-player-custom-filters ",")
       options)
      (push "-af" options))
    (with-current-buffer buffer
      (emacspeak-m-player-mode)
      (setq emacspeak-m-player-resource resource
            emacspeak-m-player-url-p
            (and resource (string-match "^http" resource)))
      (when emacspeak-m-player-url-p
        (setq emacspeak-m-player-url resource))
      (unless emacspeak-m-player-url-p
        (when resource
          (setq resource (expand-file-name resource))
          (emacspeak-speak-load-directory-settings)
          (setq emacspeak-m-player-directory (file-name-directory resource)))
        (unless emacspeak-media-dynamic-playlist
          (if   (file-directory-p resource)
              (setq file-list (emacspeak-m-player-directory-files resource))
            (setq file-list (list resource)))))
      (setq emacspeak-media-dynamic-playlist nil) ; consume it
      (setq options
            (cond
             ((and play-list  (listp play-list)(< 4   (car play-list)))
              (nconc options
                     (list "-allow-dangerous-playlist-parsing" "-playlist"
                           resource)))
             (playlist-p
              (nconc options (list "-playlist" resource)))
             (file-list (nconc options file-list))
             (t
              (nconc options (list resource)))))
      (setq buffer-undo-list t)
      (setq emacspeak-m-player-process
            (apply
             #'start-process "MPLayer" buffer
             emacspeak-mplayer options))
      (set-process-sentinel
       emacspeak-m-player-process #'ems--repeat-sentinel)
      (set-process-filter  emacspeak-m-player-process #'ems--mp-filter)
      (setq emacspeak-m-player-paused nil)
      (when
          (and
           emacspeak-m-player-directory
           (file-exists-p emacspeak-m-player-directory))
        (cd emacspeak-m-player-directory)
        (emacspeak-amark-load))
      (when (called-interactively-p 'interactive)
        (message
         "Playing   %s"
         (cond
          ((null resource)
           (format
            "Dynamic playlist with %s tracks and duration %s"
            (length file-list) duration))
          ((file-directory-p resource)
           (car (last (split-string resource "/" t))))
          (t
           (abbreviate-file-name (file-name-nondirectory resource)))))))))

;;;###autoload
(defun emacspeak-m-player-using-openal ()
  "Use openal.  "
  (interactive)
  (cl-declare (special emacspeak-m-player-options
                       emacspeak-m-player-openal-options))
  (let ((emacspeak-m-player-options
         (append emacspeak-m-player-options
                 emacspeak-m-player-openal-options)))
    (call-interactively #'emacspeak-m-player )))

(defvar emacspeak-m-player-hrtf-options
  '("-af" "hrtf=s" "-af" "resample=48000")
  "Additional options to use built-in HRTF.")

;;;###autoload
(defun emacspeak-m-player-using-hrtf ()
  "Add af resample=48000,hrtf to startup options.
This will work if the soundcard is set to 48000."
  (interactive)
  (cl-declare (special
               emacspeak-m-player-options emacspeak-m-player-hrtf-options))
  (let ((emacspeak-m-player-options
         (append emacspeak-m-player-options
                 emacspeak-m-player-hrtf-options)))
    (call-interactively #'emacspeak-m-player)))

;;;###autoload
(defun emacspeak-m-player-shuffle ()
  "M-Player with shuffle turned on."
  (interactive)
  (cl-declare (special emacspeak-m-player-options))
  (let ((emacspeak-m-player-options
         (append emacspeak-m-player-options (list "-shuffle"))))
    (call-interactively #'emacspeak-m-player)))

;;;###autoload
(defun emacspeak-m-player-loop (&optional raw)
  "M-Player with repeat indefinitely  turned on.
Interactive prefix `raw' reads a raw URL."
  (interactive "P")
  (cl-declare (special emacspeak-m-player-options))
  (let ((emacspeak-m-player-options
         (append emacspeak-m-player-options (list "-loop" "0"))))
    (cond
     (raw (emacspeak-m-player (read-from-minibuffer "URL: ")))
     (t (call-interactively #'emacspeak-m-player)))))

;;;  Table of slave commands:

(defvar emacspeak-m-player-command-list nil
  "Cache of MPlayer slave commands.")

(defun emacspeak-m-player-command-list ()
  "Return MPlayer slave command table, populating it if
necessary."
  (cl-declare (special emacspeak-m-player-command-list))
  (cond
   (emacspeak-m-player-command-list emacspeak-m-player-command-list)
   (t
    (let ((commands
           (split-string
            (shell-command-to-string
             (format "%s -input cmdlist"
                     emacspeak-mplayer))
            "\n" 'omit-nulls)))
      (setq emacspeak-m-player-command-list
            (cl-loop  for c in commands
                      collect
                      (split-string c " " 'omit-nulls)))))))

;;;  commands

(defun emacspeak-m-player-toggle-extrastereo ()
  "Toggle application of extrastereo filter to all streams."
  (interactive )
  (cl-declare (special emacspeak-m-player-custom-filters))
  (cond
   ((member "extrastereo" emacspeak-m-player-custom-filters)
    (setq
     emacspeak-m-player-custom-filters
     (remove "extrastereo" emacspeak-m-player-custom-filters))
    (message "Effect extrastereo no longer applied to all streams")
    (emacspeak-auditory-icon 'off))
   (t
    (cl-pushnew "extrastereo" emacspeak-m-player-custom-filters
                :test #'string-equal)
    (message "Effect extrastereo  applied to all streams")
    (emacspeak-auditory-icon 'on))))

(defun emacspeak-m-player-get-position ()
  "Return list (position filename length)  to use as an amark. "
  (cl-declare (special emacspeak-m-player-process))
  (with-current-buffer (process-buffer emacspeak-m-player-process)
    ;; dispatch command twice to avoid flakiness in mplayer
    (ems--mp-send
     "get_time_pos\nget_file_name\nget_time_length\n")
    (let* ((output
            (ems--mp-send
             "get_time_pos\nget_file_name\nget_time_length\n") )
           (lines (when output (split-string output "\n" 'omit-nulls)))
           (fields
            (cl-loop
             for l in lines
             collect (cl-second (split-string l "=")))))
      (list
       (format "%s" (cl-first fields))  ; position
       (if (cl-second fields)
           (substring (cl-second  fields) 1 -1)
         "")
       (format "%s" (cl-third fields))))))

(defun emacspeak-m-player-filename ()
  "Return filename of current  track."
  (substring ;; strip quotes
   (cl-second
    (split-string
     (ems--mp-send "get_file_name\n")
     "="))
   1 -1))

(defun emacspeak-m-player-scale-speed (factor)
  "Scale speed by factor."
  (interactive "nFactor:")
  (ems--mp-send
   (format "af_add scaletempo=scale=%f:speed=pitch" factor)))

(defun emacspeak-m-player-slower ()
  "Slow down playback. "
  (interactive)
  (emacspeak-m-player-scale-speed 0.9091))

(defun emacspeak-m-player-faster ()
  "Speed up  playback. "
  (interactive)
  (emacspeak-m-player-scale-speed 1.1))

(defun emacspeak-m-player-half-speed ()
  "Scale speed by 0.5."
  (interactive)
  (emacspeak-m-player-scale-speed 0.5))

(defun emacspeak-m-player-double-speed()
  "Scale speed by 2.0"
  (interactive)
  (emacspeak-m-player-scale-speed 2.0))

(defun emacspeak-m-player-reset-speed ()
  "Reset  speed."
  (interactive)
  (ems--mp-send
   "speed_set 1.0"))

(defun emacspeak-m-player-skip-tracks (step)
  "Skip tracks."
  (interactive"nSkip Tracks:")
  (unless (zerop step)
    (ems--mp-send
     (format "pt_step %d" step))))

(defun emacspeak-m-player-previous-track ()
  "Previous track."
  (interactive)
  (emacspeak-m-player-skip-tracks -1))

(defun emacspeak-m-player-next-track ()
  "Next track."
  (interactive)
  (emacspeak-m-player-skip-tracks 1))

(defun emacspeak-m-player-play-tree-up (step)
  "Move within the play tree."
  (interactive
   (list
    (read-from-minibuffer "Move by: ")))
  (ems--mp-send
   (format "pt_up %s" step)))

(defun emacspeak-m-player-alt-src-step (step)
  "Move within an ASF playlist."
  (interactive
   (list
    (read-from-minibuffer "Move by: ")))
  (ems--mp-send
   (format "alt_src_step %s" step)))

(defun emacspeak-m-player-seek-relative (offset)
  "Seek  by offset from current position.
Time offset can be specified as a number of seconds, or as HH:MM:SS."
  (interactive
   (list
    (read-from-minibuffer "Offset: ")))
  (when (string-match ":" offset)
    (setq offset (ems--duration-to-seconds offset)))
  (ems--mp-send (format "seek %s" offset)))

(defun emacspeak-m-player-seek-percentage (pos)
  "Seek  to absolute pos in percent."
  (interactive
   (list
    (read-from-minibuffer "Seek to percentage: ")))
  (ems--mp-send
   (format "seek %s 1" pos)))

(defun emacspeak-m-player-seek-absolute (pos)
  "Seek  to absolute pos in seconds.
The time position can also be specified as HH:MM:SS."
  (interactive
   (list
    (read-from-minibuffer "Seek to time position: ")))
  (when (string-match ":" pos)
    (setq pos (ems--duration-to-seconds pos)))
  (ems--mp-send (format "seek %s 2" pos)))

(defun emacspeak-m-player-start-track()
  "Move to beginning."
  (interactive)
  (emacspeak-m-player-seek-absolute "0"))

(defun emacspeak-m-player-end-track()
  "Move to end."
  (interactive)
  (emacspeak-m-player-seek-absolute "99"))

(defun emacspeak-m-player-backward-10s ()
  "Move back 10 seconds."
  (interactive)
  (emacspeak-m-player-seek-relative "-10"))

(defun emacspeak-m-player-forward-10s ()
  "Move forward 10 seconds."
  (interactive)
  (emacspeak-m-player-seek-relative "10"))

(defun emacspeak-m-player-backward-1min ()
  "Move back 1 minute."
  (interactive)
  (emacspeak-m-player-seek-relative "-60"))

(defun emacspeak-m-player-forward-1min ()
  "Move forward by 1 minute."
  (interactive)
  (emacspeak-m-player-seek-relative "60"))

(defun emacspeak-m-player-backward-10min ()
  "Move backward ten minutes."
  (interactive)
  (emacspeak-m-player-seek-relative "-600"))

(defun emacspeak-m-player-forward-10min ()
  "Move forward ten minutes."
  (interactive)
  (emacspeak-m-player-seek-relative "600"))

(defun emacspeak-m-player-pause ()
  "Pause or unpause."
  (interactive)
  (cl-declare (special emacspeak-m-player-paused))
  (dtk-stop 'all)
  (ems--mp-send "pause")
  (setq emacspeak-m-player-paused (not emacspeak-m-player-paused)))

(defvar ems--m-player-mark "00-LastStopped"
  "Name used to  mark position where we stopped.")

(defun emacspeak-m-player-quit ()
  "Quit."
  (interactive)
  (cl-declare (special
               emacspeak-amark-list ems--m-player-mark
               emacspeak-m-player-url emacspeak-m-player-process))
  (repeat-exit)
  (let ((kill-buffer-query-functions nil)
        (emacspeak-speak-messages nil))
    (when (eq (process-status emacspeak-m-player-process) 'run)
      (let ((buffer (process-buffer emacspeak-m-player-process)))
        (with-current-buffer buffer
          (when emacspeak-m-player-url
            (let ((time  (cl-first (emacspeak-m-player-get-position))))
              (setq
               emacspeak-m-player-media-history
               (cl-remove-if
                #'(lambda(u)
                    (string=
                     (cl-first (split-string u "#"))
                     (cl-first
                      (split-string emacspeak-m-player-url "#"))))
                emacspeak-m-player-media-history))
              (cl-pushnew
               (format
                "%s#%s"
                (cl-first (split-string emacspeak-m-player-url "#"))
                time)
               emacspeak-m-player-media-history
               :test #'string=)))
          ;;dont amark shortcut streams
          (unless
              (or
               emacspeak-m-player-url-p
               (and emacspeak-m-player-resource
                (string-match
                 emacspeak-media-shortcuts-directory
                 emacspeak-m-player-resource))
               (cl-minusp (emacspeak-m-player-get-length)))
            (emacspeak-m-player-amark-add ems--m-player-mark)
            (emacspeak-m-player-amark-save))
          (ems--mp-send "quit")
          (unless (eq (process-status emacspeak-m-player-process) 'exit)
            (delete-process  emacspeak-m-player-process))
          (setq emacspeak-m-player-process nil)
          (and (buffer-live-p buffer) (kill-buffer buffer))
          (emacspeak-speak-mode-line)
          (emacspeak-auditory-icon 'close-object))))))

(defun emacspeak-m-player-volume-up ()
  "Volume up."
  (interactive)
  (ems--mp-send "volume 1")
  (emacspeak-auditory-icon 'right))

(defun emacspeak-m-player-volume-down ()
  "Volume down."
  (interactive)
  (ems--mp-send "volume -1")
  (emacspeak-auditory-icon 'left))

(defvar-local emacspeak-m-player-active-filters nil
  "Active filters.")

(defun emacspeak-m-player-volume-change (value)
  "Set volume."
  (interactive"sChange Volume to:")
  (cl-declare (special emacspeak-m-player-active-filters))
  (cl-pushnew "volume" emacspeak-m-player-active-filters :test #'string=)
  (ems--mp-send
   (format "volume %s, 1" value)))

(defun emacspeak-m-player-balance ()
  "Set left/right balance."
  (interactive)
  (ems--mp-send
   (format "balance %s"
           (read-from-minibuffer "Balance -- Between -1 and 1:"))))

(defun emacspeak-m-player-slave-command (command)
  "Dispatch slave command."
  (interactive
   (list
    (completing-read "Slave Command: " (emacspeak-m-player-command-list))))
  (with-current-buffer (process-buffer emacspeak-m-player-process)
    (let* ((args
            (when (cdr (assoc command emacspeak-m-player-command-list))
              (read-from-minibuffer
               (mapconcat
                #'identity
                (cdr (assoc command emacspeak-m-player-command-list))
                " "))))
           (result
            (ems--mp-send (format "%s %s" command args))))
      (when result
        (setq result (replace-regexp-in-string  "^ans_" "" result))
        (setq result (replace-regexp-in-string  "_" " " result)))
      (when (called-interactively-p 'interactive)
        (message   "%s"
                   (or result "Waiting")))
      result)))

(defun emacspeak-m-player-delete-filter (filter)
  "Delete filter."
  (interactive
   (list
    (with-current-buffer (process-buffer emacspeak-m-player-process)
      (completing-read "Filter:"
                       (or emacspeak-m-player-active-filters
                           emacspeak-m-player-filters nil nil)))))
  (cl-declare (special emacspeak-m-player-filters
                       emacspeak-m-player-active-filters))
  (with-current-buffer (process-buffer emacspeak-m-player-process)
    (let* ((result (ems--mp-send (format "af_del %s" filter))))
      (setq emacspeak-m-player-active-filters
            (remove  filter emacspeak-m-player-active-filters))
      (when result
        (setq result (replace-regexp-in-string  "^ans_" "" result))
        (setq result (replace-regexp-in-string  "_" " " result)))
      (message   "%s" (or result "Waiting")))))

(defun emacspeak-m-player-display-percent ()
  "Display current percentage."
  (interactive)
  (dtk-speak-and-echo (emacspeak-m-player-slave-command "get_percent_pos")))

(defun emacspeak-m-player-stream-info (&optional toggle-cue)
  "Speak and display metadata.
Interactive prefix arg toggles automatic cueing of ICY info updates."
  (interactive "P")
  (cl-declare (special ems--media-data
                       emacspeak-m-player-cue-info))
  (with-current-buffer (process-buffer emacspeak-m-player-process)
    (unless   ems--media-data  (error "No metadata"))
    (let* ((m (ems--media-data-info  ems--media-data))
           (info (and m (cl-second (split-string m "=")))))
      (when toggle-cue
        (setq emacspeak-m-player-cue-info
              (not emacspeak-m-player-cue-info))
        (when  emacspeak-m-player-cue-info
          (emacspeak-auditory-icon
           (if emacspeak-m-player-cue-info 'on 'off))))
      (dtk-speak-and-echo (format "%s" (or info  "No Stream Info"))))))

(defun emacspeak-m-player-get-length ()
  "Display length of track."
  (interactive)
  (let ((a
         (read
          (cl-second (split-string (ems--mp-send "get_time_length") "=")))))
    (dtk-speak-and-echo a)
    a))

(defconst emacspeak-m-player-display-cmd
  "get_time_pos\nget_percent_pos\nget_time_length\nget_file_name\n"
  "Command we send MPlayer to display position.")

(defun emacspeak-m-player-show-pos ()
  "Display current position in track."
  (interactive)
  (cl-declare (special emacspeak-m-player-display-cmd))
  (let ((fields nil)
        (result (ems--mp-send emacspeak-m-player-display-cmd)))
    (when result
      (setq result (replace-regexp-in-string  "^ans_" "" result))
      (setq fields
            (mapcar
             #'(lambda (s) (split-string s "="))
             (split-string  result "\n"))))
    (cond
     (fields                       ; speak them after audio formatting
      (cl-loop
       for f in fields do
       (put-text-property 0 (length (cl-first f))
                          'personality 'voice-smoothen (cl-first f))
       (put-text-property 0 (length (cl-second f))
                          'personality 'voice-bolden (cl-second f)))
      (setq result
            (cl-loop
             for f in fields
             collect
             (concat (cl-first f) " " (cl-second f) "\n ")))
      (tts-with-punctuations 'some
                             (dtk-speak-and-echo (apply #'concat result))))
     (t (dtk-speak-and-echo "Waiting")))))

(defconst emacspeak-m-player-filters
  '( "extrastereo" "extrastereo=1.5" "volnorm" "surround"
     "channels=2:2:1:0:0:1"
     "channels=1:0:0:0:1"
     "channels=1:1:0:1:1"
     "channels=1:2"
     "ladspa=bs2b:bs2b:700:4.5"
     "ladspa=ZamAutoSat-ladspa.so:ZamAutoSat:"
     "ladspa=tap_pinknoise.so:tap_pinknoise:0.5:-2:-12"
     "ladspa=ZamHeadX2-ladspa.so:ZamHeadX2:0:60:2.5"
     "ladspa=ZamHeadX2-ladspa.so:ZamHeadX2:0:30:2.5"
     "ladspa=ZamHeadX2-ladspa.so:ZamHeadX2:0:45:2.5"
     "ladspa=ZamHeadX2-ladspa.so:ZamHeadX2:0:15:2.5"
     "ladspa=amp:amp_stereo:2"
     "ladspa=amp:amp_stereo:0.5"
     (concat  "ladspa=tap_autopan:tap_autopan:.0016:100:1.5,"
              " ladspa=tap_autopan:tap_autopan:.06:33:2")
     "bs2b profile=cmoy" "bs2b profile=jmeier" "bs2b")
  "Table of MPlayer filters.")

(defun emacspeak-m-player-add-autopan ()
  "Add autopan effect."
  (interactive)
  (emacspeak-m-player-add-filter
   (concat
    "ladspa=tap_autopan:tap_autopan:.0016:100:1,"
    "ladspa=tap_autopan:tap_autopan:.016:33:1")))

(defun emacspeak-m-player-add-autosat ()
  "Add ZamAutoSat (auto saturation) effect."
  (interactive)
  (emacspeak-m-player-add-filter
   "ladspa=ZamAutoSat-ladspa.so:ZamAutoSat:"))

(defun emacspeak-m-player-add-filter (filter-name &optional edit)
  "Adds  filter with completion.
 Optional interactive prefix arg `edit' edits the."
  (interactive
   (list
    (completing-read "Filter:"
                     emacspeak-m-player-filters
                     nil nil)
    current-prefix-arg))
  (cl-declare (special emacspeak-m-player-process
                       emacspeak-m-player-active-filters))
  (when edit
    (setq filter-name
          (read-from-minibuffer
           "Edit Filter: " filter-name)))
  (when (process-live-p  emacspeak-m-player-process)
    (push filter-name emacspeak-m-player-active-filters)
    (ems--mp-send (format "af_add %s" filter-name))))

(defun emacspeak-m-player-left-channel ()
  "Play both channels on left."
  (interactive)
  (let ((filter-name "channels=2:1:0:0:1:0"))
    (when (process-live-p  emacspeak-m-player-process)
      (ems--mp-send (format "af_add %s" filter-name)))))

(defun emacspeak-m-player-add-loop (&optional prompt)
  "Add loop 10 is default."
  (interactive "P")
  (when (process-live-p  emacspeak-m-player-process)
    (ems--mp-send
     (format "loop %d" (if prompt (read-number "Count:") 10)))))

(defun emacspeak-m-player-right-channel ()
  "Play on right channel."
  (interactive)
  (let ((filter-name "channels=2:1:0:1:1:1"))
    (when (process-live-p  emacspeak-m-player-process)
      (ems--mp-send (format "af_add %s" filter-name)))))

(defun emacspeak-m-player-balance-channels ()
  "Mono to stereo."
  (interactive)
  (let ((filter-name "channels=1:2"))
    (when (process-live-p  emacspeak-m-player-process)
      (ems--mp-send (format "af_add %s" filter-name)))))
(defun emacspeak-m-player-clear-filters ()
  "Clear all filters"
  (interactive)
  (cl-declare (special emacspeak-m-player-process
                       emacspeak-m-player-active-filters))
  (setq emacspeak-m-player-active-filters nil)
  (when (process-live-p emacspeak-m-player-process)
    (ems--mp-send "af_clr")
    (emacspeak-auditory-icon 'delete-object)))

(defun emacspeak-m-player-customize ()
  "Use Customize to set MPlayer options."
  (interactive)
  (customize-variable 'emacspeak-m-player-options)
  (goto-char (point-min))
  (search-forward "INS"))

;;;  Media History:

;;;###autoload
(defvar emacspeak-m-player-media-history nil
  "Record media urls we played.")

(defun emacspeak-m-player-rem-history (url)
  "Remove URL from media history"
  (interactive (list (emacspeak-eww-read-url)))
  (cl-declare (special emacspeak-m-player-media-history))
  (setq emacspeak-m-player-media-history
        (cl-remove-if
         #'(lambda(u) (string= u url))
         emacspeak-m-player-media-history))
  (emacspeak-auditory-icon 'delete-object)
  (kill-buffer)
  (call-interactively 'emacspeak-m-player-browse-history))

;;;###autoload
(defun emacspeak-m-player-from-history (&optional prefix)
  "Play media from the front of media-history.
   Interactive prefix arg invokes media history browser."
  (interactive "P")
  (cl-declare (special emacspeak-m-player-media-history))
  (cond
   ((and prefix emacspeak-m-player-media-history) 
    (call-interactively 'emacspeak-m-player-browse-history))
   (emacspeak-m-player-media-history
    (emacspeak-m-player-url (car emacspeak-m-player-media-history )))
   (t (error "No media history"))))

(defvar emacspeak-m-player-history-map
  (let ((map (make-sparse-keymap)))
    (define-key map ";" 'emacspeak-eww-play-media-at-point)
    (define-key map "k" 'shr-copy-url)
    (define-key map "r" 'emacspeak-m-player-rem-history)
    map)
  "Keymap used in media history browser.")

(defun emacspeak-m-player-browse-history ()
  "Create a  media history browser from media-history."
  (interactive )
  (cl-declare (special
               emacspeak-m-player-history-map
               emacspeak-m-player-media-history))
  (with-temp-buffer
    (insert "<html>\n
<head><title>Emacspeak Media History</title></head>\n
<body>\n<p>Press ';' to play, 'r'  to remove the link  from the history.</p>\n
<ol>\n")
    (cl-loop
     for u in emacspeak-m-player-media-history do
     (insert
      (format "<li><a href='%s'>%s: %s</a></li>\n"
              u (url-host (url-generic-parse-url u)) (file-name-base  u))))
    (insert "</ol></body></html>\n")
    (add-hook
     'browse-url-of-file-hook
     #'(lambda ()
         (let ((inhibit-read-only t))
           (put-text-property
            (point-min) (point-max)
            'keymap  emacspeak-m-player-history-map)
           (pop browse-url-of-file-hook)
           (emacspeak-auditory-icon 'open-object)
           (emacspeak-speak-line))))
    (call-interactively #'browse-url-of-buffer)))

;;;  Reset Options:

(defun emacspeak-m-player-reset-options ()
  "Reset MPlayer options."
  (interactive)
  (cl-declare (special emacspeak-m-player-default-options
                       emacspeak-m-player-options))
  (setq emacspeak-m-player-options
        (copy-sequence emacspeak-m-player-default-options))
  (message "Reset options."))

;;;  equalizer

;; Equalizer presets:
;; Cloned from VLC and munged for m-player.
;; VLC uses -20db .. 20db; mplayer uses -12db .. 12db
;; See http://advantage-bash.blogspot.com/2013/05/mplayer-presets.html

(defvar ems--eq-presets
  '(
      ("flat" . [0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0])
      ("classical" . [0.0 0.0 0.0 0.0 0.0 -4.4 -4.4 -4.4 -5.8 -6.5])
      ("club" . [0.0 0.0 4.8 3.3 3.3 3.3 1.9 0.0 0.0 0.0])
      ("dance" . [5.7 4.3 1.4 0.0 0.0 -3.4 -4.4 -4.3 0.0 0.0])
      ("full-bass" . [-4.8 5.7 5.7 3.3 1.0 -2.4 -4.8 -6.3 -6.7 -6.7])
      ("full-bass-and-treble" . [4.3 3.3 0.0 -4.4 -2.9 1.0 4.8 6.7 7.2 7.2])
      ("full-treble" . [-5.8 -5.8 -5.8 -2.4 1.4 6.7 9.6 9.6 9.6 10.1])
      ("headphones" . [2.8 6.7 3.3 -2.0 -1.4 1.0 2.8 5.7 7.7 8.6])
      ("large-hall" . [6.2 6.2 3.3 3.3 0.0 -2.9 -2.9 -2.9 0.0 0.0])
      ("live" . [-2.9 0.0 2.4 3.3 3.3 3.3 2.4 1.4 1.4 1.4])
      ("party" . [4.3 4.3 0.0 0.0 0.0 0.0 0.0 0.0 4.3 4.3])
      ("pop" . [-1.0 2.8 4.3 4.8 3.3 0.0 -1.4 -1.4 -1.0 -1.0])
      ("reggae" . [0.0 0.0 0.0 -3.4 0.0 3.8 3.8 0.0 0.0 0.0])
      ("rock" . [4.8 2.8 -3.4 -4.8 -2.0 2.4 5.3 6.7 6.7 6.7])
      ("ska" . [-1.4 -2.9 -2.4 0.0 2.4 3.3 5.3 5.7 6.7 5.8])
      ("soft" . [2.8 1.0 0.0 -1.4 0.0 2.4 4.8 5.7 6.7 7.2])
      ("soft-rock" . [2.4 2.4 1.4 0.0 -2.4 -3.4 -2.0 0.0 1.4 5.3])
      ("techno" . [4.8 3.3 0.0 -3.4 -2.9 0.0 4.8 5.7 5.8 5.3]))
  "MPlayer equalizer presets.")

(defsubst ems--eq-preset-get (name)
  "Return vector of numbers for specified preset."
  (cl-declare (special  ems--eq-presets))
  (cdr (assoc name ems--eq-presets)))

(defconst emacspeak-m-player-equalizer (make-vector 10 0)
  "Vector holding equalizer settings.")

(defconst  emacspeak-m-player-equalizer-bands
  ["31.25 Hz"
   "62.50 Hz"
   "125.00 Hz"
   "250.00 Hz"
   "500.00 Hz"
   "1.00 kHz"
   "2.00 kHz"
   "4.00 kHz"
   "8.00 kHz"
   "16.00 kHz"]
  "Center frequencies for the 10 equalizer bands in MPlayer.")

(defun emacspeak-m-player-eq-controls (v)
  "Manipulate values in  vector using minibuffer.
Applies  the resulting value at each step."
  (interactive)
  (cl-declare (special emacspeak-m-player-equalizer-bands))
  (let ((column 0)
        (key nil)
        (result  (mapconcat #'number-to-string v  ":"))
        (continue t))
    ;; First, clear any equalizers in effect:
    (ems--mp-send "af_del equalizer")
    ;; Apply specified vector:
    (ems--mp-send (format "af_add equalizer=%s" result))
    (while  continue
      (setq key
            (read-key-sequence
             (format "G%s:%s (%s)" column (aref v column)
                     (aref emacspeak-m-player-equalizer-bands column))))
      (cond
       ((equal key "e")
        (aset
         v column
         (read-number
          (format
           "Value for G%s:%s (%s)"
           column (aref v column)
           (aref emacspeak-m-player-equalizer-bands column)))))
       ((equal key [left])
        (setq column (% (+ 9  column) 10)))
       ((equal key [right])
        (setq column (% (1+ column) 10)))
       ((equal key [up])
        (aset v   column (min 12 (1+ (aref v column)))))
       ((equal key [down])
        (aset v   column (max -12 (1- (aref v column)))))
       ((equal key [prior])
        (aset v   column (min 12 (+ 4  (aref v column)))))
       ((equal key [next])
        (aset v   column (max -12 (- (aref v column)  4))))
       ((equal key [home])
        (aset v   column 12))
       ((equal key [end])
        (aset v   column -12))
       ((equal key "\C-g")
        (ems--mp-send "af_del equalizer")
        (error "Did not change equalizer."))
       ((equal key "\C-m")
        (setq emacspeak-m-player-equalizer v)
        (setq continue nil))
       (t (message "Invalid key")))
      (setq result (mapconcat #'number-to-string v  ":"))
      (ems--mp-send
       (format "af_cmdline equalizer %s" result)))
    result))

(defun emacspeak-m-player-add-equalizer (&optional reset)
  "Add equalizer.  Equalizer is updated as each change
is made, and the final effect set by pressing RET.  Interactive prefix
arg `reset' starts with all filters set to 0."
  (interactive "P")
  (cl-declare (special emacspeak-m-player-process emacspeak-m-player-equalizer
                       emacspeak-m-player-active-filters))
  (cond
   ((eq 'run  (process-status emacspeak-m-player-process))
    (emacspeak-m-player-eq-controls
     (if reset  (make-vector 10 0)
       emacspeak-m-player-equalizer))
    (emacspeak-auditory-icon 'close-object)
    (push "equalizer" emacspeak-m-player-active-filters))
   (t (message "No stream playing at present."))))

(defun emacspeak-m-player-eq-preset  (name)
  "Prompts for  and apply equalizer preset.

The following presets are available:

flat classical club dance full-bass full-bass-and-treble
 full-treble headphones large-hall live party pop reggae rock
 ska soft soft-rock techno "
  (interactive
   (list
    (completing-read
     "MPlayer Equalizer Preset:"
     ems--eq-presets
     nil 'must-match)))
  (cl-declare (special emacspeak-m-player-active-filters))
  (cl-declare (special
               ems--eq-presets
               emacspeak-m-player-equalizer))
  (let ((result nil)
        (p (ems--eq-preset-get name)))
    (setq emacspeak-m-player-equalizer p)
    (setq result  (mapconcat #'number-to-string p  ":"))
    (ems--mp-send "af_del equalizer")
    (cl-pushnew "equalizer" emacspeak-m-player-active-filters :test #'string=)
    (ems--mp-send (format "af_add equalizer=%s" result))))

;;;  Key Bindings:

(cl-declaim (special emacspeak-m-player-mode-map))

(defvar emacspeak-m-player-bindings
  '(
    ("%" emacspeak-m-player-display-percent)
    ("(" emacspeak-m-player-left-channel)
    (")" emacspeak-m-player-right-channel)
    ("'" emacspeak-m-player-add-loop)
    ("+" emacspeak-m-player-volume-up)
    ("," emacspeak-m-player-backward-10s)
    ("-" emacspeak-m-player-volume-down)
    ("." emacspeak-m-player-forward-10s)
    ("/" emacspeak-m-player-restore-process)
    (";" emacspeak-m-player-pop-to-player)
    ("<" emacspeak-m-player-backward-1min)
    ("<down>" emacspeak-m-player-forward-1min)
    ("<end>" emacspeak-m-player-end-track)
    ("<home>" emacspeak-m-player-start-track)
    ("<left>" emacspeak-m-player-backward-10s)
    ("<next>" emacspeak-m-player-forward-10min)
    ("<prior>" emacspeak-m-player-backward-10min)
    ("<right>" emacspeak-m-player-forward-10s)
    ("<up>" emacspeak-m-player-backward-1min)
    ("=" emacspeak-m-player-volume-up)
    (">" emacspeak-m-player-forward-1min)
    ("?" emacspeak-m-player-show-pos)
    ("T" emacspeak-speak-brief-time)
    ("A" emacspeak-m-player-amark-add)
    ("b" emacspeak-m-player-balance-channels)
    ("C" emacspeak-m-player-clear-filters)
    ("C-a" emacspeak-amark-browse)
    ("C-l" ladspa)
    ("DEL" emacspeak-m-player-reset-speed)
    ("E" emacspeak-m-player-add-equalizer)
    ("G" emacspeak-m-player-seek-percentage)
    ("L" emacspeak-m-player-get-length)
    ("M" emacspeak-m-player-show-data)
    ("M-," emacspeak-m-player-set-clip-start)
    ("M-." emacspeak-m-player-set-clip-end)
    ("O" emacspeak-m-player-reset-options)
    ("P" emacspeak-m-player-apply-reverb)
    ("Q" emacspeak-m-player-quit)
    ("R" emacspeak-m-player-edit-reverb)
    ("S" emacspeak-m-player-amark-save)
    ("SPC" emacspeak-m-player-pause)
    ("[" emacspeak-m-player-slower)
    ("\\" emacspeak-m-player-persist-process)
    ("]" emacspeak-m-player-faster)
    ("a" emacspeak-m-player-add-autopan)
    ("c" emacspeak-m-player-slave-command)
    ("d" emacspeak-m-player-delete-filter)
    ("e" emacspeak-m-player-eq-preset)
    ("f" emacspeak-m-player-add-filter)
    ("g" emacspeak-m-player-seek-absolute)
    ("h" emacspeak-m-player-from-history)
    ("i" emacspeak-m-player-stream-info)
    ("j" emacspeak-m-player-amark-jump)
    ("k" emacspeak-m-player-quit)
    ("l" emacspeak-m-player-store-link)
    ("m" emacspeak-m-player-mode-line)
    ("n" emacspeak-m-player-next-track)
    ("o" emacspeak-m-player-customize)
    ("p" emacspeak-m-player-previous-track)
    ("r" emacspeak-m-player-seek-relative)
    ("s" emacspeak-m-player-scale-speed)
    ("t" emacspeak-m-player-skip-tracks)
    ("v" emacspeak-m-player-volume-change)
    ("w" emacspeak-m-player-write-clip)
    ("x" emacspeak-m-player-pan)
    ("z" emacspeak-m-player-add-autosat)
    ("{" emacspeak-m-player-half-speed)
    ("}" emacspeak-m-player-double-speed)
    )
  "M-Player Key bindings.")

(cl-loop
 for k in emacspeak-m-player-bindings do
 (emacspeak-keymap-update  emacspeak-m-player-mode-map k))

(put 'emacspeak-m-player-shuffle 'repeat-map 'emacspeak-m-player-mode-map)
(put 'emacspeak-m-player-loop 'repeat-map 'emacspeak-m-player-mode-map)
(put 'emacspeak-multimedia 'repeat-map  'emacspeak-m-player-mode-map)
(put 'emacspeak-m-player-using-openal
     'repeat-map
     'emacspeak-m-player-mode-map)
(put 'emacspeak-m-player-volume-set 'repeat-map
     'emacspeak-m-player-mode-map)
;;; repeat-mode
(map-keymap
 (lambda (_key cmd)
   (when
       (and
        (symbolp cmd)
        (not (eq cmd 'digit-argument)))
     (put cmd 'repeat-map 'emacspeak-m-player-mode-map)))
 emacspeak-m-player-mode-map)

;;; disable on stop:
(put 'emacspeak-m-player-quit  'repeat-map nil)
(put 'ladspa  'repeat-map nil)

(defun emacspeak-m-player-volume-set (&optional arg)
  "Set Volume in steps from 1 to 9."
  (interactive "P")
  (cl-declare (special last-input-event))
  (let ((vol-step
         (cond
          ((not (called-interactively-p 'interactive)) arg)
          (t
           (read (format "%c" last-input-event))))))
    (cl-assert
     (and (integerp vol-step) (< 0 vol-step) (< vol-step 10))
     nil "Volume step should be between 1 and 9")
    (emacspeak-m-player-volume-change (* 11 vol-step))
    (emacspeak-auditory-icon 'button)))

(cl-loop
 for i from 1 to 9 do
 (define-key emacspeak-m-player-mode-map
             (kbd (format "%s" i)) 'emacspeak-m-player-volume-set))

;;;  YouTube:

(defsubst ems--m-p-get-yt-audio-first-fmt (url)
  "First available audio format code for   YT URL"
  (substring
   (shell-command-to-string
    (format
     "%s -F '%s' | grep '^[0-9]'   |grep audio |  head -1 | cut -f 1 -d ' '"
     emacspeak-ytdl url))
   0 -1))

(defsubst ems--m-p-get-yt-audio-last-fmt (url)
  "Last  available (best audio format code for   YT URL"
  (substring
   (shell-command-to-string
    (format
     "%s -F '%s' | grep '^[0-9]'   | grep audio |tail -1 | cut -f 1 -d ' '"
     emacspeak-ytdl url))
   0 -1))

(declare-function emacspeak-google-result-url-prefix "emacspeak-google" nil)
;; yt player using mplayer is broken  due to xml manifests
(declare-function
 emacspeak-google-canonicalize-result-url "emacspeak-google" (url))
(declare-function mpv-start "mpv" (&rest args))
(declare-function
 emacspeak-empv-play-url "emacspeak-empv" (url &optional left-channel))

;;;  pause/resume

(defun emacspeak-m-player-pause-or-resume ()
  "Pause/resume if m-player is running. For use  in
emacspeak-silence-hook."
  (cl-declare (special emacspeak-m-player-process))
  (when (and emacspeak-m-player-process
             (eq 'run (process-status emacspeak-m-player-process)))
    (emacspeak-m-player-pause)))
(add-hook 'emacspeak-silence-hook 'emacspeak-m-player-pause-or-resume)

;;;  AMarks:

(defun emacspeak-m-player-amark-add (name &optional prompt-position)
  "Set AMark `name' at current position.
Interactive prefix arg prompts for position.
As the default, use current position."
  (interactive "sAMark Name:\nP")
  (let* ((pos (emacspeak-m-player-get-position))
         (file-name (cl-second pos)))
    (when
        (and file-name  (not (zerop (length file-name))))
      (setq pos
            (cond
             (prompt-position (read-number "Position: "))
             (t  (cl-first pos))))
      (emacspeak-amark-add file-name name pos)
      (message "Added Amark %s in %s at %s" name file-name pos))))

(defun emacspeak-m-player-store-link ()
  "Store an org-link to currently playing stream at current position."
  (interactive)
  (cl-declare (special emacspeak-m-player-url org-stored-links))
  (when emacspeak-m-player-url
    (cl-pushnew
     `(
       ,(format "e-media:%s#%s"
                (cl-first (split-string emacspeak-m-player-url "#"))
                (cl-first (emacspeak-m-player-get-position)))
       "URL")
     org-stored-links)))

(defun ems-file-index (name file-list)
  "Return index of name in file-list."
  (cl-position (expand-file-name name) file-list :test #'string=))

(defun emacspeak-m-player-amark-jump ()
  "Jump to AMark."
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (with-current-buffer
      (process-buffer emacspeak-m-player-process)
    (let ((amark (call-interactively #'emacspeak-amark-find)))
      (cond ;; seek if in current  file
       ((string=
         (emacspeak-m-player-filename)
         (emacspeak-amark-path amark))
        (emacspeak-m-player-seek-absolute (emacspeak-amark-position amark)))
       (t (emacspeak-amark-play amark))))))

;;;  Adding specific Ladspa filters:

;; tap_reverb filter

(defvar emacspeak-m-player-reverb-filter
  '("ladspa=tap_reverb:tap_reverb" 10000 -2 -10 1 1 1 1 6)
  "Tap Reverb Settings."
  )

(defun emacspeak-m-player-edit-reverb ()
  "Edit ladspa reverb filter.
  You need to use mplayer built with ladspa support, and have package
  tap-reverb already installed."
  (interactive)
  (cl-declare (special emacspeak-m-player-reverb-filter))
  (let ((ladspa(or  (getenv "LADSPA_PATH")
                    "/usr/lib/ladspa"))
        (filter nil)
        (orig-filter
         (mapconcat
          #'(lambda (v) (format "%s" v))
          emacspeak-m-player-reverb-filter ":")))
    (unless ladspa (error "Environment variable LADSPA_PATH not set."))
    (unless (getenv "LADSPA_PATH") (setenv "LADSPA_PATH" ladspa))
    (unless (file-exists-p (expand-file-name "tap_reverb.so" ladspa))
      (error "Package tap_reverb not installed."))
    (setq filter (read-from-minibuffer "Reverb: " orig-filter))
    (setq emacspeak-m-player-reverb-filter(split-string filter ":"))
    (ems--mp-send "af_clr")
    (ems--mp-send (format "af_add %s" filter))))

(defconst emacspeak-m-player-reverb-table
  '(
    ("AfterBurn"   0)
    ("AfterBurn (Long)"   1)
    ("Ambience"   2)
    ("Ambience (Thick)"   3)
    ("Ambience (Thick) - HD"   4)
    ("Cathedral"   5)
    ("Cathedral - HD"   6)
    ("Drum Chamber"   7)
    ("Garage"   8)
    ("Garage (Bright)"   9)
    ("Gymnasium"   10)
    ("Gymnasium (Bright)"   11)
    ("Gymnasium (Bright) - HD"   12)
    ("Hall (Small)"   13)
    ("Hall (Medium)"   14)
    ("Hall (Large)"   15)
    ("Hall (Large) - HD"   16)
    ("Plate (Small)"   17)
    ("Plate (Medium)"   18)
    ("Plate (Large)"   19)
    ("Plate (Large) - HD"   20)
    ("Pulse Chamber"   21)
    ("Pulse Chamber (Reverse)"   22)
    ("Resonator (96 ms)"   23)
    ("Resonator (152 ms)"   24)
    ("Resonator (28 ms)"   25)
    ("Room (Small)"   26)
    ("Room (Medium)"   27)
    ("Room (Large)"   28)
    ("Room (Large) - HD"   29)
    ("Slap Chamber"   30)
    ("Slap Chamber - HD"   31)
    ("Slap Chamber (Bright)"   32)
    ("Slap Chamber (Bright) - HD"   33)
    ("Smooth Hall (Small)"   34)
    ("Smooth Hall (Medium)"   35)
    ("Smooth Hall (Large)"   36)
    ("Smooth Hall (Large) - HD"   37)
    ("Vocal Plate"   38)
    ("Vocal Plate - HD"   39)
    ("Warble Chamber"   40)
    ("Warehouse"   41)
    ("Warehouse - HD"   42))
  "Table mapping tap reverb preset names to values.")

(defconst emacspeak-m-player-tap-reverbs
  '(("AfterBurn" 2.8)
    ("AfterBurn (Long)" 4.8)
    ("Ambience" 1.1)
    ("Ambience (Thick)" 1.2)
    ("Ambience (Thick) - HD" 1.2)
    ("Cathedral" 10)
    ("Cathedral - HD" 10)
    ("Drum Chamber" 3.6)
    ("Garage" 2.3)
    ("Garage (Bright)" 2.3)
    ("Gymnasium" 5.9)
    ("Gymnasium (Bright)" 5.9)
    ("Gymnasium (Bright) - HD" 5.9)
    ("Hall (Small)" 2.0)
    ("Hall (Medium)" 3.0)
    ("Hall (Large)" 5.1)
    ("Hall (Large) - HD" 5.1)
    ("Plate (Small)" 1.7)
    ("Plate (Medium)" 2.6)
    ("Plate (Large)" 5.7)
    ("Plate (Large) - HD" 5.7)
    ("Pulse Chamber" 3.1)
    ("Pulse Chamber (Reverse)" 3.1)
    ("Resonator (96 ms)" 4.0)
    ("Resonator (152 ms)" 4.2)
    ("Resonator (208 ms)" 5.1)
    ("Room (Small)" 1.9)
    ("Room (Medium)" 2.8)
    ("Room (Large)" 4.4)
    ("Room (Large) - HD" 4.4)
    ("Slap Chamber" 2.3)
    ("Slap Chamber - HD" 2.9)
    ("Slap Chamber (Bright)" 3.4)
    ("Slap Chamber (Bright) - HD" 3.7)
    ("Smooth Hall (Small)" 1.8)
    ("Smooth Hall (Medium)" 3.0)
    ("Smooth Hall (Large)" 5.9)
    ("Smooth Hall (Large) - HD" 5.9)
    ("Vocal Plate" 3.1)
    ("Vocal Plate - HD" 3.1)
    ("Warble Chamber" 4.0)
    ("Warehouse" 6.0)
    ("Warehouse - HD" 6.0))
  "Table of tap-reverb presets along with recommended decay values.")

(defun emacspeak-m-player-apply-reverb (preset)
  "Prompt for and apply a reverb preset.
  You need to use mplayer built with ladspa support, and have package
  tap-reverb already installed."
  (interactive
   (list
    (let ((completion-ignore-case t))
      (completing-read "Preset: "
                       emacspeak-m-player-tap-reverbs
                       nil 'must-match))))
  (cl-declare (special emacspeak-m-player-tap-reverbs
                       emacspeak-m-player-reverb-table
                       emacspeak-m-player-process
                       emacspeak-m-player-reverb-filter))
  (let ((setting (assoc preset emacspeak-m-player-tap-reverbs))
        (ladspa (getenv "LADSPA_PATH"))
        (filter-spec nil)
        (filter nil))
    (unless (process-live-p emacspeak-m-player-process)
      (error "No media playing  currently."))
    (unless ladspa
      (setq ladspa (setenv "LADSPA_PATH" "/usr/lib/ladspa")))
    (unless (file-exists-p (expand-file-name "tap_reverb.so" ladspa))
      (error "Package tap_reverb not installed."))
    (setq filter-spec
          `("ladspa=tap_reverb:tap_reverb"
            ,(round (* 1000 (cl-second setting))) ;  delay  in ms
            0 -7                               ; dry and wet db
            1 1 1 1
                                        ; preset name
            ,(cadr (assoc (cl-first setting)
                          emacspeak-m-player-reverb-table))))
    (setq emacspeak-m-player-reverb-filter filter-spec)
    (setq filter (mapconcat #'(lambda (v) (format "%s" v)) filter-spec ":"))
    (ems--mp-send "af_clr")
    (ems--mp-send
     (format "af_add %s" filter))
    (emacspeak-auditory-icon 'button)))

;;;  Play RSS Stream:

;;;###autoload
(defun emacspeak-m-player-play-rss (rss-url)
  "Play an RSS stream."
  (interactive
   (list
    (emacspeak-eww-read-url)))
  (let* ((file (make-temp-file  "rss-media" nil ".m3u"))
         (buffer (find-file-noselect file)))
    (message "Retrieving playlist.")
    (with-current-buffer buffer
      (insert-buffer-substring
       (emacspeak-xslt-xml-url
        (emacspeak-xslt-get "rss2m3u.xsl")
        rss-url))
      (save-buffer))
    (emacspeak-m-player file 'playlist)))

;;;  Use locate to construct media playlist:

(defvar emacspeak-locate-media-map
  (let ((map (make-sparse-keymap)))
    (define-key map ";" 'emacspeak-dired-play-duration)
    (define-key  map (kbd "M-;") 'emacspeak-m-player-add-dynamic)
    (define-key map "\C-m" 'emacspeak-locate-play-results-as-playlist)
    map)
  "Keymap used to play locate results.")
(add-hook 'locate-mode-hook
          #'emacspeak-pronounce-refresh-pronunciations)
;;;###autoload
(defun emacspeak-m-player-locate-media (pattern)
  "Locate media matching  pattern.  The results can be
played as a play-list by pressing [RET] on the first line, see
 \\[emacspeak-dired-open-this-file] locally bound to C-RET
to play  tracks."
  (interactive "sSearch Pattern: ")
  (cl-declare  (special emacspeak-media-extensions
                        locate-command locate-make-command-line))
  (let ((inhibit-read-only t)
        (case-fold-search t)
        (locate-make-command-line
         #'(lambda (s) (list locate-command "-i" "--regexp" s))))
    (locate-with-filter
     (mapconcat #'identity
                (split-string pattern)
                "[ '/\"_.,-]")
     emacspeak-media-extensions)
    (goto-char (point-min))
    (message "Buffer: %s" (current-buffer))
    (put-text-property
     (point-min) (point-max)
     'keymap  emacspeak-locate-media-map)
    (emacspeak-auditory-icon 'open-object)
    (rename-buffer (format "Media  matching %s" pattern))
    (emacspeak-speak-mode-line)))

;;;  MultiPlayer Support:

(defun emacspeak-m-player-persist-process (&optional name)
  "Persists  m-player process instance by renaming its buffer.
Optional interactive prefix arg prompts for name to use for  player."
  (interactive "P")
  (cl-declare (special  emacspeak-m-player-process))
  (when (process-live-p emacspeak-m-player-process)
    (with-current-buffer  (process-buffer emacspeak-m-player-process)
      (set (make-local-variable 'emacspeak-m-player-process)
           emacspeak-m-player-process)
      (set-default 'emacspeak-m-player-process nil)
      (rename-buffer
       (if name
           (format "*%s*" (read-from-minibuffer "Name: "))
         "Persisted-M-Player*")
       'unique))
    (when (called-interactively-p 'interactive)
      (emacspeak-auditory-icon 'task-done)
      (dtk-notify-say
       "persisted current process. You can now start another player."))))

(defun emacspeak-m-player-restore-process ()
  "Restore emacspeak-m-player-process from current buffer.
Check first if current buffer is in emacspeak-m-player-mode."
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (unless (eq major-mode 'emacspeak-m-player-mode)
    (error "This is not an MPlayer buffer."))
  (let ((proc
         (or (get-buffer-process (current-buffer))
             emacspeak-m-player-process)))
    (cond
     ((process-live-p proc)
      (setq emacspeak-m-player-process proc)
      (set-default 'emacspeak-m-player-process proc)
      (emacspeak-auditory-icon 'open-object)
      (message "Restored  player process."))
     (t (error "No live player here.")))))

;;;  Panning:

(defvar-local emacspeak-m-player-panner 0
  "The 11 pre-defined panning locations.")

(defun emacspeak-m-player-pan ()
  "Pan from left to right   and back  one step at a time."
  (interactive)
  (cl-declare (special emacspeak-m-player-panner emacspeak-m-player-process))
  (unless (process-live-p emacspeak-m-player-process) (error "No   player."))
  (let* ((this (abs  (/ emacspeak-m-player-panner 10.0)))
         (pan (format "%.1f:%.1f" (- 1  this)  this)))
    (ems--mp-send  "af_del pan, channels")
    (ems--mp-send (format "af_add pan=2:%s:%s" pan pan))
    (setq emacspeak-m-player-panner (1+ emacspeak-m-player-panner))
    (when (= 10 emacspeak-m-player-panner)
      (setq emacspeak-m-player-panner -10))
    (message "Panned  to %.1f %.1f" (- 1 this) this)))

;;;  Apply Ladspa to MPlayer:

(defun emacspeak-m-player-ladspa-cmd (plugin)
  "Convert Ladspa Plugin to M-Player command args."
  (format
   "ladspa=%s:%s:%s"
   (ladspa-plugin-library plugin) (ladspa-plugin-label plugin)
   (mapconcat #'ladspa-control-value (ladspa-plugin-controls plugin) ":")))

(defun emacspeak-m-player-add-ladspa ()
  "Apply plugin to running MPlayer.
Copies  invocation string to kill-ring so it can be added easily to
our pre-defined filters if appropriate."
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (unless (eq major-mode 'ladspa-mode) (error "This is not a Ladspa buffer"))
  (unless (get-text-property (point) 'ladspa)
    (error "No Ladspa Plugin here."))
  (unless (process-live-p emacspeak-m-player-process)
    (error "No running MPlayer."))
  (let ((result nil)
        (plugin (get-text-property (point) 'ladspa))
        (args nil))
    (when
        (cl-some
         #'null
         (mapcar #'ladspa-control-value (ladspa-plugin-controls plugin)))
      (ladspa-instantiate))
    (setq args (emacspeak-m-player-ladspa-cmd plugin))
    (kill-new args)
    (setq result
          (ems--mp-send (format "af_add %s" args)))
    (when (called-interactively-p 'interactive)
      (message   "%s"
                 (or result "Waiting")))))

(defun emacspeak-m-player-delete-ladspa ()
  "Delete plugin from  running MPlayer."
  (interactive)
  (cl-declare (special emacspeak-m-player-process))
  (unless (eq major-mode 'ladspa-mode) (error "This is not a Ladspa buffer"))
  (unless (process-live-p emacspeak-m-player-process)
    (error "No running MPlayer."))

  (ems--mp-send "af_del ladspa"))

;;;  Clipping:

(defcustom emacspeak-m-player-clips
  (expand-file-name "~/mp3/clips")
  "Directory where we store clips."
  :type 'directory
  :group 'emacspeak-m-player)

;; Functionality restored from emacspeak-alsaplayer.el:

(defvar-local clip-start nil
  "Start position of clip.")

(defvar-local clip-end nil
  "End position of clip.")

(defun emacspeak-m-player-set-clip-start    ( )
  "Set start of clip. "
  (interactive )
  (setq clip-start
        (read-number
         "Start Time: "
         (read (cl-first (emacspeak-m-player-get-position)))))
  (when  (called-interactively-p 'interactive)
    (message "Start: %s" clip-start)
    (emacspeak-auditory-icon 'mark-object)))

(defun emacspeak-m-player-set-clip-end    ()
  "Set end of clip mark."
  (interactive )
  (cl-declare (special clip-end))
  (setq clip-end
        (read-number
         "End time: "
         (read (cl-first (emacspeak-m-player-get-position)))))
  (when  (called-interactively-p 'interactive)
    (message "End: %s" clip-end)
    (emacspeak-auditory-icon 'mark-object)))

(defun emacspeak-m-player-write-clip ()
  "Split selected range using SoX"
  (interactive)
  (cl-declare (special emacspeak-sox emacspeak-m-player-clips
                       clip-end clip-start))
  (cl-assert
   emacspeak-sox  nil "SoX needs to be installed to use this command.")
  (cl-assert
   (eq major-mode 'emacspeak-m-player-mode) nil "Not in an MPlayer buffer.")
  (cl-assert (numberp clip-start) nil "Set start of clip with M-[")
  (cl-assert (numberp clip-end) nil "Set end of clip with M-]")
  (let ((file (cl-second (emacspeak-m-player-get-position)))
        (tmp
         (concat
          (make-temp-name
           (expand-file-name  "clip-" temporary-file-directory))
          ".wav")))
    (shell-command
     (format "%s '%s' %s  trim %s %s"
             emacspeak-sox file tmp
             clip-start
             (- clip-end clip-start)))
    (shell-command
     (format
      "%s '%s' '%s/clip-%s-%s-%s'"
      emacspeak-sox tmp
      emacspeak-m-player-clips
      clip-start clip-end file))
    (delete-file tmp)
    (message
     "Clip saved to '%s/clip-%s-%s-%s'."
     emacspeak-m-player-clips
     clip-start clip-end file)))

(provide 'emacspeak-m-player)
;;;  end of file

