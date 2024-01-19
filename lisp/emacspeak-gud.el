;;; emacspeak-gud.el --- Speech enable debugger -*- lexical-binding: t; -*-
;;
;; $Author: tv.raman.tv $
;; DescriptionEmacspeak extensions for gud interaction
;; Keywords:emacspeak, audio interface to emacs debuggers
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



;;; Commentary:
;; Provide additional advice to ease debugger interaction with gud
;;; Code:

;;;  requires
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)

;;;   Advise key helpers:

(defadvice gud-display-line (after emacspeak pre act comp)
  "Speak the error line"
  (cl-declare (special gud-overlay-arrow-position))
  (let ((marker gud-overlay-arrow-position))
    (emacspeak-auditory-icon 'large-movement)
    (and marker
         (marker-buffer marker)
         (marker-position marker)
         (save-current-buffer
           (set-buffer (marker-buffer marker))
           (goto-char (marker-position marker))
           (emacspeak-speak-line)))))

(cl-loop
 for f in
 '(
   gud-break
   gud-tbreak
   gud-remove
   gud-step
   gud-stepi
   gud-next
   gud-nexti
   gud-cont
   gud-finish
   gud-jump
   )
 do
 (eval
  `(defadvice ,f (around emacspeak pre act comp)
     "Silence minibuffer message that echoes command."
     (ems-with-messages-silenced
      ad-do-it
      (emacspeak-auditory-icon 'select-object)
      ad-return-value))))

;;;  Advise interactive commands:

(provide  'emacspeak-gud)
 

