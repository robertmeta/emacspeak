;;; emacspeak-webspace.el --- Webspaces -*- lexical-binding: t; -*-
;;
;; $Author: tv.raman.tv $
;; Description: WebSpace provides smart updates from the Web.
;; Keywords: Emacspeak, Audio Desktop webspace
;;;  LCD Archive entry:

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;; A speech interface to Emacs |
;; 
;; $Revision: 4532 $ |
;; Location https://github.com/tvraman/emacspeak
;; 

;;;  Copyright:
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
;; MERCHANTABILITY or FITNWEBSPACE FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to
;; the Free Software Foundation, 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;  introduction

;;; Commentary:
;; WEBSPACE == Smart Web Gadgets For The Emacspeak Desktop
;;; Code:

;;;  Required modules

(eval-when-compile (require 'cl-lib))
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'ring)
(require 'derived)
(require 'gweb)
(require 'emacspeak-feeds)

;;;  WebSpace Mode:

;; Define a derived-mode called WebSpace that is generally useful for
;; hypetext display.

(define-derived-mode emacspeak-webspace-mode special-mode
  "Webspace Interaction"
  "Major mode for Webspace interaction.\n\n
\\{emacspeak-webspace-mode-map}")

(cl-declaim (special emacspeak-webspace-mode-map))
(set-keymap-parent emacspeak-webspace-mode-map button-buffer-map)
(cl-loop for k in
         '(
           ("q" bury-buffer)
           ("." emacspeak-webspace-filter)
           ("'" emacspeak-speak-rest-of-buffer)
           ("<" beginning-of-buffer)
           (">" end-of-buffer)
           ("/" search-forward)
           ("?" search-backward)
           ("y" emacspeak-webspace-yank-link)
           ("n" forward-button)
           ("p" backward-button)
           ("f" forward-button)
           ("b" backward-button))
         do
         (emacspeak-keymap-update emacspeak-webspace-mode-map k))

(defun emacspeak-webspace-act-on-link (action &rest args)
  "Apply action to link under point."
  (let ((link (get-text-property (point) 'link)))
    (if link
        (apply action link args)
      (message "No link under point."))))

(defun emacspeak-webspace-yank-link ()
  "Yank link under point into kill ring."
  (interactive)
  (let ((button (button-at (point))))
    (cond
     (button (emacspeak-auditory-icon 'yank-object)
             (message "%s"
                      (kill-new
                       (or (cl-second (button-get button 'feed))
                           (button-get button 'link)
                           (button-get button 'url)))))
     (t (error "No link under point")))))

(defun emacspeak-webspace-open ()
  "Open headline at point by following its link property."
  (interactive)
  (emacspeak-webspace-act-on-link 'browse-url))

(defun emacspeak-webspace-filter ()
  "Open headline at point and filter for content."
  (interactive)
  (let ((link (get-text-property (point) 'link)))
    (if link
        (emacspeak-we-xslt-filter
         emacspeak-we-recent-xpath-filter
         link 'speak)
      (message "No link under point."))))

;;;  WebSpace Display:

(defun emacspeak-webspace-display (infolet)
  "Displays specified infolet.
Infolets use the same structure as mode-line-format and header-line-format.
Generates auditory and visual display."
  (cl-declare (special header-line-format))
  (setq header-line-format infolet)
  (dtk-speak (format-mode-line header-line-format))
  (emacspeak-auditory-icon 'progress))

;;;###autoload
(define-prefix-command 'emacspeak-webspace 'emacspeak-webspace-keymap)

(cl-declaim (special emacspeak-webspace-keymap))

(cl-loop for k in
         '(
           ("h" emacspeak-webspace-headlines)
           (" " emacspeak-webspace-headlines-browse)
           )
         do
         (define-key emacspeak-webspace-keymap (cl-first k) (cl-second k)))

;;;  Headlines:

(cl-defstruct emacspeak-webspace-fs
  feeds
  titles ; (title url)
  timer slow-timer
  index)

(defvar emacspeak-webspace-headlines nil
  "Feedstore structure to use a continuously updating ticker.")

(defvar emacspeak-webspace-headlines-period '(0 1800 0)
  "How often we fetch from a feed.")
(defun emacspeak-webspace-feed-titles (feed-url)
  "Return a list  `((title url)...) given an RSS/Atom  feed  URL."
  (cl-declare (special emacspeak-xslt-directory emacspeak-xslt
                       emacspeak-curl g-curl-options))
  (with-temp-buffer
    (shell-command
     (format "%s %s %s | %s %s - "
             emacspeak-curl g-curl-options feed-url
             emacspeak-xslt
             (expand-file-name "feed-titles.xsl" emacspeak-xslt-directory))
     (current-buffer))
    (goto-char (point-min))
    ;; newline -> spc
    (while (re-search-forward "\n" nil t) (replace-match " "))
    (goto-char (point-min))
    (read (current-buffer))))

(defun emacspeak-webspace-headlines-fetch (feed)
  "Add headlines from specified feed to our cache.
Newly found headlines are inserted into the ring within our feedstore."
  (cl-declare (special emacspeak-webspace-headlines
                       emacspeak-webspace-headlines-period))
  (let* ((last-update (get-text-property 0 'last-update feed))
         (titles (emacspeak-webspace-fs-titles emacspeak-webspace-headlines))
         (new-titles nil))
    (when                     ; check if we need to add from this feed
        (or (null last-update)          ;  at most every half hour
            (time-less-p
             emacspeak-webspace-headlines-period  (time-since last-update)))
      (put-text-property 0 1 'last-update (current-time) feed)
      (setq new-titles (emacspeak-webspace-feed-titles feed))
      (when (listp new-titles)
        (mapc
         #'(lambda (h)
             (unless (ring-member titles h)
               (ring-insert titles h)))
         new-titles)))))

(defun emacspeak-webspace-fs-next (fs)
  "Return next feed and increment index for fs."
  (let ((feed-url
         (aref
          (emacspeak-webspace-fs-feeds fs)
          (emacspeak-webspace-fs-index fs))))
    (setf (emacspeak-webspace-fs-index fs)
          (% (1+ (emacspeak-webspace-fs-index fs))
             (length (emacspeak-webspace-fs-feeds fs))))
    feed-url))

(defun emacspeak-webspace-headlines-populate ()
  "populate fs with headlines from all feeds."
  (cl-declare (special emacspeak-webspace-headlines))
  (dotimes (_i (length (emacspeak-webspace-fs-feeds
                        emacspeak-webspace-headlines)))
    (condition-case nil
        (emacspeak-webspace-headlines-fetch
         (emacspeak-webspace-fs-next emacspeak-webspace-headlines))
      (error nil))))

(defun emacspeak-webspace-headlines-refresh ()
  "Update headlines."
  (cl-declare (special emacspeak-webspace-headlines))
  (with-local-quit
    (emacspeak-webspace-headlines-fetch
     (emacspeak-webspace-fs-next emacspeak-webspace-headlines)))
  (emacspeak-auditory-icon 'progress)
  t)

(defun emacspeak-webspace-headlines-update ()
  "Setup news updates.
Updated headlines found in emacspeak-webspace-headlines."
  (interactive)
  (cl-declare (special emacspeak-webspace-headlines))
  (let ((timer nil)
        (slow-timer nil))
    (setq timer
          (run-with-idle-timer
           60 t 'emacspeak-webspace-headlines-refresh))
    (setq slow-timer
          (run-with-idle-timer
           3600
           t 'emacspeak-webspace-headlines-populate))
    (setf (emacspeak-webspace-fs-timer emacspeak-webspace-headlines) timer)
    (setf
     (emacspeak-webspace-fs-slow-timer emacspeak-webspace-headlines)
     slow-timer)))

(defun emacspeak-webspace-next-headline ()
  "Return next headline to display."
  (cl-declare (special emacspeak-webspace-headlines))
  (let ((titles (emacspeak-webspace-fs-titles emacspeak-webspace-headlines)))
    (cond
     ((ring-empty-p titles)
      (emacspeak-webspace-headlines-refresh)
      "No News Is Good News")
     (t (let ((h (ring-remove titles 0)))
          (ring-insert-at-beginning titles h)
          (cl-first h))))))
(defcustom emacspeak-webspace-feeds
  nil
  "Feeds to use in Headline Ticker."
  :type '(repeat (string :tag "URL"))
  :group 'emacspeak-webspace)

;;;###autoload
(defun emacspeak-webspace-headlines ()
  "Startup Headlines ticker using RSS/Atom  feeds."
  (interactive)
  (cl-declare (special emacspeak-webspace-headlines
                       emacspeak-webspace-feeds))
  (cl-assert
   emacspeak-webspace-feeds
   t "First add some feeds to emacspeak-webspace-feeds.")
  (unless emacspeak-webspace-headlines
    (setq emacspeak-webspace-headlines
          (make-emacspeak-webspace-fs
           :feeds
           (apply #'vector emacspeak-webspace-feeds)
           :titles (make-ring (* 10 (length emacspeak-feeds)))
           :index 0)))
  (unless (emacspeak-webspace-fs-timer emacspeak-webspace-headlines)
    (call-interactively 'emacspeak-webspace-headlines-update))
  (emacspeak-webspace-display '((:eval (emacspeak-webspace-next-headline)))))

(defvar emacspeak-webspace-headlines-buffer "*Headlines*"
  "Name of buffer that displays headlines.")

(defun emacspeak-webspace-headlines-browse ()
  "Display buffer of browsable headlines."
  (interactive)
  (cl-declare (special emacspeak-webspace-headlines
                       emacspeak-webspace-headlines-buffer))
  (unless emacspeak-webspace-headlines
    (error "No cached headlines in this Emacs session."))
  (with-current-buffer
      (get-buffer-create emacspeak-webspace-headlines-buffer)
    (setq buffer-undo-list t)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (goto-char (point-min))
      (insert "Press enter to open stories.\n\n")
      (put-text-property (point-min) (point) 'face font-lock-doc-face)
      (cl-loop
       for h in
       (delq nil
             (ring-elements
              (emacspeak-webspace-fs-titles emacspeak-webspace-headlines)))
       and position  from 1
       do
       (insert (format "\n%d\t" position))
       (emacspeak-webspace-headlines-insert-button h))
      (goto-char (point-min))
      (flush-lines "^ *$")
      (emacspeak-webspace-mode)))
  (switch-to-buffer emacspeak-webspace-headlines-buffer)
  (goto-char (point-min))
  (emacspeak-auditory-icon 'open-object)
  (emacspeak-speak-mode-line))

(define-button-type 'emacspeak-webspace-headline
  'follow-link t
  'link nil
  'help-echo "Open Headline"
  'action #'emacspeak-webspace-headline-action)

(defun emacspeak-webspace-headline-action (button)
  "Open story associated with this button."
  (browse-url (button-get button 'link)))

(defun emacspeak-webspace-headlines-insert-button (headline)
  "Insert a button for this headline at point."
  (insert-text-button
   (car headline)
   'type 'emacspeak-webspace-headline
   'link (cadr headline)))

;;;  Feed Reader:

;; In memory of Google Reader:

(defvar emacspeak-webspace-reader-buffer "Reader"
  "Name of Reader buffer.")

;; New Reader using emacspeak-feeds:

(define-button-type 'emacspeak-webspace-feed-link
  'follow-link t
  'feed nil
  'help-echo "Open Feed"
  'action #'emacspeak-webspace-feed-reader-action)

(defun emacspeak-webspace-feed-reader-insert-button (feed)
  "Insert a button for this feed at point."
  (insert-text-button
   (cl-first feed) ; label
   'type 'emacspeak-webspace-feed-link
   'feed feed))

(defun emacspeak-webspace-feed-reader-action (button)
  "Open feed associated with this button."
  (emacspeak-feeds-browse-feed (button-get button 'feed)))

;;;###autoload
(defun emacspeak-webspace-feed-reader (&optional refresh)
  "Display Feed Reader Feed list in a WebSpace buffer.
Optional interactive prefix arg forces a refresh."
  (interactive "P")
  (cl-declare (special emacspeak-webspace-reader-buffer))
  (when (or refresh
            (not (buffer-live-p (get-buffer
                                 emacspeak-webspace-reader-buffer))))
    (emacspeak-webspace-feed-reader-create))
  (switch-to-buffer emacspeak-webspace-reader-buffer)
  (goto-char (point-min))
  (emacspeak-speak-mode-line)
  (emacspeak-auditory-icon 'open-object))
(defun emacspeak-webspace-feed-reader-create ()
  "Prepare Reader buffer."
  (cl-declare (special emacspeak-feeds emacspeak-webspace-reader-buffer))
  (with-current-buffer (get-buffer-create emacspeak-webspace-reader-buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (goto-char (point-min))
      (insert "Press enter to open feeds.\n\n")
      (put-text-property (point-min) (point) 'face font-lock-doc-face)
      (cl-loop for f in emacspeak-feeds
               and position  from 1
               do
               (insert (format "%d\t" position))
               (emacspeak-webspace-feed-reader-insert-button f)
               (insert "\n"))
      (switch-to-buffer emacspeak-webspace-reader-buffer)
      (emacspeak-webspace-mode))))

(provide 'emacspeak-webspace)
;;;  end of file

