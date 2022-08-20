;;; image-dired-dired.el --- Dired specific commands for Image-Dired  -*- lexical-binding: t -*-

;; Copyright (C) 2005-2022 Free Software Foundation, Inc.

;; Author: Mathias Dahl <mathias.rem0veth1s.dahl@gmail.com>
;; Keywords: multimedia

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'image-dired)

(defcustom image-dired-append-when-browsing nil
  "Append thumbnails in thumbnail buffer when browsing.
If non-nil, using `image-dired-next-line-and-display' and
`image-dired-previous-line-and-display' will leave a trail of thumbnail
images in the thumbnail buffer.  If you enable this and want to clean
the thumbnail buffer because it is filled with too many thumbnails,
just call `image-dired-display-thumb' to display only the image at point.
This value can be toggled using `image-dired-toggle-append-browsing'."
  :group 'image-dired
  :type 'boolean)

(defcustom image-dired-dired-disp-props t
  "If non-nil, display properties for Dired file when browsing.
Used by `image-dired-next-line-and-display',
`image-dired-previous-line-and-display' and `image-dired-mark-and-display-next'.
If the database file is large, this can slow down image browsing in
Dired and you might want to turn it off."
  :group 'image-dired
  :type 'boolean)

;;;###autoload
(defun image-dired-dired-toggle-marked-thumbs (&optional arg)
  "Toggle thumbnails in front of file names in the Dired buffer.
If no marked file could be found, insert or hide thumbnails on the
current line.  ARG, if non-nil, specifies the files to use instead
of the marked files.  If ARG is an integer, use the next ARG (or
previous -ARG, if ARG<0) files."
  (interactive "P" dired-mode)
  (dired-map-over-marks
   (let ((image-pos  (dired-move-to-filename))
         (image-file (dired-get-filename nil t))
         thumb-file
         overlay)
     (when (and image-file
                (string-match-p (image-file-name-regexp) image-file))
       (setq thumb-file (image-dired-get-thumbnail-image image-file))
       ;; If image is not already added, then add it.
       (let ((thumb-ov (cl-loop for ov in (overlays-in (point) (1+ (point)))
                                if (overlay-get ov 'thumb-file) return ov)))
         (if thumb-ov
             (delete-overlay thumb-ov)
	   (put-image thumb-file image-pos)
	   (setq overlay
                 (cl-loop for ov in (overlays-in (point) (1+ (point)))
                          if (overlay-get ov 'put-image) return ov))
	   (overlay-put overlay 'image-file image-file)
	   (overlay-put overlay 'thumb-file thumb-file)))))
   arg             ; Show or hide image on ARG next files.
   'show-progress) ; Update dired display after each image is updated.
  (add-hook 'dired-after-readin-hook
            'image-dired-dired-after-readin-hook nil t))

(defun image-dired-dired-after-readin-hook ()
  "Relocate existing thumbnail overlays in Dired buffer after reverting.
Move them to their corresponding files if they still exist.
Otherwise, delete overlays."
  (mapc (lambda (overlay)
          (when (overlay-get overlay 'put-image)
            (let* ((image-file (overlay-get overlay 'image-file))
                   (image-pos (dired-goto-file image-file)))
              (if image-pos
                  (move-overlay overlay image-pos image-pos)
                (delete-overlay overlay)))))
        (overlays-in (point-min) (point-max))))

(defun image-dired-next-line-and-display ()
  "Move to next Dired line and display thumbnail image."
  (interactive nil dired-mode)
  (dired-next-line 1)
  (image-dired-display-thumbs
   t (or image-dired-append-when-browsing nil) t)
  (if image-dired-dired-disp-props
      (image-dired-dired-display-properties)))

(defun image-dired-previous-line-and-display ()
  "Move to previous Dired line and display thumbnail image."
  (interactive nil dired-mode)
  (dired-previous-line 1)
  (image-dired-display-thumbs
   t (or image-dired-append-when-browsing nil) t)
  (if image-dired-dired-disp-props
      (image-dired-dired-display-properties)))

(defun image-dired-toggle-append-browsing ()
  "Toggle `image-dired-append-when-browsing'."
  (interactive nil dired-mode)
  (setq image-dired-append-when-browsing
        (not image-dired-append-when-browsing))
  (message "Append browsing %s"
           (if image-dired-append-when-browsing
               "on"
             "off")))

(defun image-dired-mark-and-display-next ()
  "Mark current file in Dired and display next thumbnail image."
  (interactive nil dired-mode)
  (dired-mark 1)
  (image-dired-display-thumbs
   t (or image-dired-append-when-browsing nil) t)
  (if image-dired-dired-disp-props
      (image-dired-dired-display-properties)))

(defun image-dired-toggle-dired-display-properties ()
  "Toggle `image-dired-dired-disp-props'."
  (interactive nil dired-mode)
  (setq image-dired-dired-disp-props
        (not image-dired-dired-disp-props))
  (message "Dired display properties %s"
           (if image-dired-dired-disp-props
               "on"
             "off")))

(defun image-dired-track-thumbnail ()
  "Track current Dired file's thumb in `image-dired-thumbnail-buffer'.
This is almost the same as what `image-dired-track-original-file' does,
but the other way around."
  (let ((file (dired-get-filename))
        prop-val found window)
    (when (get-buffer image-dired-thumbnail-buffer)
      (with-current-buffer image-dired-thumbnail-buffer
        (goto-char (point-min))
        (while (and (not (eobp))
                    (not found))
          (if (and (setq prop-val
                         (get-text-property (point) 'original-file-name))
                   (string= prop-val file))
              (setq found t))
          (if (not found)
              (forward-char 1)))
        (when found
          (if (setq window (image-dired-thumbnail-window))
              (set-window-point window (point)))
          (image-dired-update-header-line))))))

(defun image-dired-dired-next-line (&optional arg)
  "Call `dired-next-line', then track thumbnail.
This can safely replace `dired-next-line'.
With prefix argument, move ARG lines."
  (interactive "P" dired-mode)
  (dired-next-line (or arg 1))
  (if image-dired-track-movement
      (image-dired-track-thumbnail)))

(defun image-dired-dired-previous-line (&optional arg)
  "Call `dired-previous-line', then track thumbnail.
This can safely replace `dired-previous-line'.
With prefix argument, move ARG lines."
  (interactive "P" dired-mode)
  (dired-previous-line (or arg 1))
  (if image-dired-track-movement
      (image-dired-track-thumbnail)))

;;;###autoload
(defun image-dired-jump-thumbnail-buffer ()
  "Jump to thumbnail buffer."
  (interactive nil dired-mode)
  (let ((window (image-dired-thumbnail-window))
        frame)
    (if window
        (progn
          (if (not (equal (selected-frame) (setq frame (window-frame window))))
              (select-frame-set-input-focus frame))
          (select-window window))
      (message "Thumbnail buffer not visible"))))

(defvar image-dired-minor-mode-map
  (let ((map (make-sparse-keymap)))
    ;; (set-keymap-parent map dired-mode-map)
    ;; Hijack previous and next line movement. Let C-p and C-b be
    ;; though...
    (define-key map "p" #'image-dired-dired-previous-line)
    (define-key map "n" #'image-dired-dired-next-line)
    (define-key map [up] #'image-dired-dired-previous-line)
    (define-key map [down] #'image-dired-dired-next-line)

    (define-key map (kbd "C-S-n") #'image-dired-next-line-and-display)
    (define-key map (kbd "C-S-p") #'image-dired-previous-line-and-display)
    (define-key map (kbd "C-S-m") #'image-dired-mark-and-display-next)

    (define-key map "\C-td" #'image-dired-display-thumbs)
    (define-key map [tab] #'image-dired-jump-thumbnail-buffer)
    (define-key map "\C-ti" #'image-dired-dired-display-image)
    (define-key map "\C-tx" #'image-dired-dired-display-external)
    (define-key map "\C-ta" #'image-dired-display-thumbs-append)
    (define-key map "\C-t." #'image-dired-display-thumb)
    (define-key map "\C-tc" #'image-dired-dired-comment-files)
    (define-key map "\C-tf" #'image-dired-mark-tagged-files)
    map)
  "Keymap for `image-dired-minor-mode'.")

(easy-menu-define image-dired-minor-mode-menu image-dired-minor-mode-map
  "Menu for `image-dired-minor-mode'."
  '("Image-dired"
    ["Display thumb for next file" image-dired-next-line-and-display]
    ["Display thumb for previous file" image-dired-previous-line-and-display]
    ["Mark and display next" image-dired-mark-and-display-next]
    "---"
    ["Create thumbnails for marked files" image-dired-create-thumbs]
    "---"
    ["Display thumbnails append" image-dired-display-thumbs-append]
    ["Display this thumbnail" image-dired-display-thumb]
    ["Display image" image-dired-dired-display-image]
    ["Display in external viewer" image-dired-dired-display-external]
    "---"
    ["Toggle display properties" image-dired-toggle-dired-display-properties
     :style toggle
     :selected image-dired-dired-disp-props]
    ["Toggle append browsing" image-dired-toggle-append-browsing
     :style toggle
     :selected image-dired-append-when-browsing]
    ["Toggle movement tracking" image-dired-toggle-movement-tracking
     :style toggle
     :selected image-dired-track-movement]
    "---"
    ["Jump to thumbnail buffer" image-dired-jump-thumbnail-buffer]
    ["Mark tagged files" image-dired-mark-tagged-files]
    ["Comment files" image-dired-dired-comment-files]
    ["Copy with EXIF file name" image-dired-copy-with-exif-file-name]))

;;;###autoload
(define-minor-mode image-dired-minor-mode
  "Setup easy-to-use keybindings for the commands to be used in Dired mode.
Note that n, p and <down> and <up> will be hijacked and bound to
`image-dired-dired-next-line' and `image-dired-dired-previous-line'."
  :keymap image-dired-minor-mode-map)

(declare-function clear-image-cache "image.c" (&optional filter))

(defun image-dired-create-thumbs (&optional arg)
  "Create thumbnail images for all marked files in Dired.
With prefix argument ARG, create thumbnails even if they already exist
\(i.e. use this to refresh your thumbnails)."
  (interactive "P" dired-mode)
  (let (thumb-name)
    (dolist (curr-file (dired-get-marked-files))
      (setq thumb-name (image-dired-thumb-name curr-file))
      ;; If the user overrides the exist check, we must clear the
      ;; image cache so that if the user wants to display the
      ;; thumbnail, it is not fetched from cache.
      (when arg
        (clear-image-cache (expand-file-name thumb-name)))
      (when (or (not (file-exists-p thumb-name))
                arg)
        (image-dired-create-thumb curr-file thumb-name)))))

;;;###autoload
(defun image-dired-display-thumbs-append ()
  "Append thumbnails to `image-dired-thumbnail-buffer'."
  (interactive nil dired-mode)
  (image-dired-display-thumbs nil t t))

;;;###autoload
(defun image-dired-display-thumb ()
  "Shorthand for `image-dired-display-thumbs' with prefix argument."
  (interactive nil dired-mode)
  (image-dired-display-thumbs t nil t))

;;;###autoload
(defun image-dired-dired-display-external ()
  "Display file at point using an external viewer."
  (interactive nil dired-mode)
  (let ((file (dired-get-filename)))
    (start-process "image-dired-external" nil
                   image-dired-external-viewer file)))

;;;###autoload
(defun image-dired-dired-display-image (&optional arg)
  "Display current image file.
See documentation for `image-dired-display-image' for more information.
With prefix argument ARG, display image in its original size."
  (interactive "P" dired-mode)
  (image-dired-display-image (dired-get-filename) arg))

(defun image-dired-copy-with-exif-file-name ()
  "Copy file with unique name to main image directory.
Copy current or all marked files in Dired to a new file in your
main image directory, using a file name generated by
`image-dired-get-exif-file-name'.  A typical usage for this if when
copying images from a digital camera into the image directory.

 Typically, you would open up the folder with the incoming
digital images, mark the files to be copied, and execute this
function.  The result is a couple of new files in
`image-dired-main-image-directory' called
2005_05_08_12_52_00_dscn0319.jpg,
2005_05_08_14_27_45_dscn0320.jpg etc."
  (interactive nil dired-mode)
  (let (new-name
        (files (dired-get-marked-files)))
    (mapc
     (lambda (curr-file)
       (setq new-name
             (format "%s/%s"
                     (file-name-as-directory
                      (expand-file-name image-dired-main-image-directory))
                     (image-dired-get-exif-file-name curr-file)))
       (message "Copying %s to %s" curr-file new-name)
       (copy-file curr-file new-name))
     files)))

;;;###autoload
(defun image-dired-mark-tagged-files (regexp)
  "Use REGEXP to mark files with matching tag.
A `tag' is a keyword, a piece of meta data, associated with an
image file and stored in image-dired's database file.  This command
lets you input a regexp and this will be matched against all tags
on all image files in the database file.  The files that have a
matching tag will be marked in the Dired buffer."
  (interactive "sMark tagged files (regexp): " dired-mode)
  (image-dired-sane-db-file)
  (let ((hits 0)
        files)
    (image-dired--with-db-file
      ;; Collect matches
      (while (search-forward-regexp "\\(^[^;\n]+\\);\\(.*\\)" nil t)
        (let ((file (match-string 1))
              (tags (split-string (match-string 2) ";")))
          (when (seq-find (lambda (tag)
                            (string-match-p regexp tag))
                          tags)
            (push file files)))))
    ;; Mark files
    (dolist (curr-file files)
      ;; I tried using `dired-mark-files-regexp' but it was waaaay to
      ;; slow.  Don't bother about hits found in other directories
      ;; than the current one.
      (when (string= (file-name-as-directory
		      (expand-file-name default-directory))
		     (file-name-as-directory
		      (file-name-directory curr-file)))
	(setq curr-file (file-name-nondirectory curr-file))
	(goto-char (point-min))
	(when (search-forward-regexp (format "\\s %s$" curr-file) nil t)
	  (setq hits (+ hits 1))
	  (dired-mark 1))))
    (message "%d files with matching tag marked" hits)))

(defun image-dired-dired-display-properties ()
  "Display properties for Dired file in the echo area."
  (interactive nil dired-mode)
  (let* ((file (dired-get-filename))
         (file-name (file-name-nondirectory file))
         (dired-buf (buffer-name (current-buffer)))
         (props (mapconcat #'identity (image-dired-list-tags file) ", "))
         (comment (image-dired-get-comment file))
         (message-log-max nil))
    (if file-name
        (message "%s"
         (image-dired-format-properties-string
          dired-buf
          file-name
          props
          comment)))))

(provide 'image-dired-dired)

;; Local Variables:
;; nameless-current-name: "image-dired"
;; End:

;;; image-dired-dired.el ends here
