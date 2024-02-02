;;; emacspeak-message.el --- Speech enable Message   -*- lexical-binding: t; -*-
;;
;; $Author: tv.raman.tv $ 
;; Description: Emacspeak extensions for posting
;; Keywords:emacspeak, audio interface to emacs posting messages
;;;   LCD Archive entry: 

;; LCD Archive Entry:
;; emacspeak| T. V. Raman |tv.raman.tv@gmail.com
;; A speech interface to Emacs |
;; 
;;  $Revision: 4532 $ | 
;; Location https://github.com/tvraman/emacspeak
;; 

;;;   Copyright:
;; Copyright (C) 1995 -- 2024, T. V. Raman 
;; Copyright (c) 1995 by T. V. Raman  
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


;;;   Introduction
;;; Commentary:
;; advice for posting message commands
;;; Code:

;;;  requires
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)

;;;  customize
(defgroup emacspeak-message nil
  "Emacspeak customizations for message mode"
  :group 'emacspeak
  :group 'message
  :prefix "emacspeak-message-")

(defcustom emacspeak-message-punctuation-mode  'all
  "Pronunciation mode to use for message buffers."
  :type '(choice
          (const  :tag "Ignore" nil)
          (const  :tag "some" some)
          (const  :tag "all" all))
  :group 'emacspeak-message)

;;;  voice mapping

(voice-setup-add-map
 '(
   (message-cited-text voice-smoothen)
   (message-header-cc voice-bolden)
   (message-header-name voice-animate)
   (message-header-newsgroups voice-bolden)
   (message-header-other voice-monotone)
   (message-header-subject voice-animate)
   (message-header-to voice-brighten)
   (message-header-xheader voice-monotone)
   (message-mml voice-brighten)
   (message-separator voice-bolden-extra)))

;;;   advice interactive commands
(cl-loop
 for f in
 '(message-send message-send-and-exit)
 do
 (eval
  `(defadvice ,f (after emacspeak pre act comp)
     "Provide auditory context"
     (when  (ems-interactive-p)
       (emacspeak-speak-mode-line)
       (emacspeak-auditory-icon 'close-object)))))

(defadvice message-goto-to (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-summary (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-subject (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-cc (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-bcc (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-fcc (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-keywords (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-newsgroups (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-followup-to (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-reply-to (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-body (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (message "Beginning of message body")))

(defadvice message-goto-signature (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-distribution (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-insert-citation-line (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-insert-to (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-insert-signature (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (message "Signed the article.")))

(defadvice message-insert-newsgroups (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-insert-courtesy-copy (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-beginning-of-line (before emacspeak pre act comp)
  "Stop speech first."
  (when (ems-interactive-p) (dtk-stop 'all)
        (emacspeak-auditory-icon 'select-object)
        (dtk-speak "beginning of line")))

(defadvice message-goto-from (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-goto-mail-followup-to (after emacspeak pre act comp)
  "speak"
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'large-movement)
    (emacspeak-speak-line)))

(defadvice message-newline-and-reformat (after emacspeak pre act comp)
  "speak."
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'fill-object)
    (message "newline and reformat")))

(add-hook 'message-mode-hook
          (lambda ()
            (dtk-set-punctuations emacspeak-message-punctuation-mode)
            (emacspeak-pronounce-refresh-pronunciations)
            (emacspeak-auditory-icon 'open-object)
            (message "Starting message %s ... done"
                     (buffer-name))))

(provide  'emacspeak-message)
  

