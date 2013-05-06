;; ox-reveal --- reveal.js Presentation Back-End for Org Export Engine

;; Copyright (C) 2013 Yujie Wen

;; Author: Yujie Wen <yjwen.ty at gmail dot com>
;; Keywords: outlines, hypermedia, slideshow, presentation

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;; Please see "Readme.org" for detail introductions.

(require 'ox-html)
(eval-when-compile (require 'cl))

(org-export-define-derived-backend reveal html

  :menu-entry
  (?R "Export to reveal.js HTML Presentation"
      ((?R "To file" org-reveal-export-to-html)))

  :options-alist
  ((:reveal-control nil "reveal_control" org-reveal-control t)
   (:reveal-progress nil "reveal_progress" org-reveal-progress t)
   (:reveal-history nil  "reveal_history" org-reveal-history t)
   (:reveal-center nil "reveal_center" org-reveal-center t)
   (:reveal-root "REVEAL_ROOT" nil org-reveal-root t)
   (:reveal-trans "REVEAL_TRANS" nil org-reveal-transition t)
   (:reveal-theme "REVEAL_THEME" nil org-reveal-theme t)
   (:reveal-hlevel "REVEAL_HLEVEL" nil nil t)
   (:reveal-mathjax nil "reveal_mathjax" org-reveal-mathjax t)
   (:reveal-mathjax-url "REVEAL_MATHJAX_URL" nil org-reveal-mathjax-url t)
   )

  :translate-alist
  ((headline . org-reveal-headline)
   (inner-template . org-reveal-inner-template)
   (item . org-reveal-item)
   (paragraph . org-reveal-paragraph)
   (template . org-reveal-template)))

(defcustom org-reveal-root "./reveal.js"
  "The root directory of reveal.js packages. It is the directory
  within which js/reveal.min.js is."
  :group 'org-export-reveal)

(defcustom org-reveal-hlevel 1
  "The minimum level of headings that should be grouped into
vertical slides."
  :group 'org-export-reveal
  :type 'integer)

(defun org-reveal--get-hlevel (info)
  "Get HLevel value safely.
If option \"REVEAL_HLEVEL\" is set, retrieve integer value from it,
else get value from custom variable `org-reveal-hlevel'."
  (let ((hlevel-str (plist-get info :reveal-hlevel)))
    (if hlevel-str (string-to-int hlevel-str)
      org-reveal-hlevel)))

(defcustom org-reveal-title-slide-template
  "<h1>%t</h1>
<h2>%a</h2>
<h2>%e</h2>
<h2>%d</h2>"
  "Format template to specify title page slide.
See `org-html-postamble-format' for the valid elements which
can be include."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-transition
  "default"
  "Reveal transistion style."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-theme
  "default"
  "Reveal theme."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-control t
  "Reveal control applet."
  :group 'org-export-reveal
  :type 'string)

(defcustom org-reveal-progress t
  "Reveal progress applet."
  :group 'org-export-reveal
  :type 'boolean)

(defcustom org-reveal-history t
  "Reveal history applet."
  :group 'org-export-reveal
  :type 'boolean)

(defcustom org-reveal-center t
  "Reveal center applet."
  :group 'org-export-reveal
  :type 'boolean)

(defcustom org-reveal-mathjax nil
  "Enable MathJax script."
  :group 'org-export-reveal
  :type 'boolean)

(defcustom org-reveal-mathjax-url
  "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"
  "Default MathJax URL."
  :group 'org-export-reveal
  :type 'string)

(defun if-format (fmt val)
  (if val (format fmt val) ""))

(defun org-reveal-headline (headline contents info)
  "Transcode a HEADLINE element from Org to HTML.
CONTENTS holds the contents of the headline. INFO is a plist
holding contextual information."
  ;; First call org-html-headline to get the formatted HTML contents.
  ;; Then add enclosing <section> tags to mark slides.
  (setq contents (or contents ""))
  (let* ((numberedp (org-export-numbered-headline-p headline info))
	 (level (org-export-get-relative-level headline info))
	 (text (org-export-data (org-element-property :title headline) info))
	 (todo (and (plist-get info :with-todo-keywords)
		    (let ((todo (org-element-property :todo-keyword headline)))
		      (and todo (org-export-data todo info)))))
	 (todo-type (and todo (org-element-property :todo-type headline)))
	 (tags (and (plist-get info :with-tags)
		    (org-export-get-tags headline info)))
	 (priority (and (plist-get info :with-priority)
			(org-element-property :priority headline)))
	 (section-number (and (org-export-numbered-headline-p headline info)
			      (mapconcat 'number-to-string
					 (org-export-get-headline-number
					  headline info) ".")))
	 ;; Create the headline text.
	 (full-text (org-html-format-headline--wrap headline info)))
    (cond
     ;; Case 1: This is a footnote section: ignore it.
     ((org-element-property :footnote-section-p headline) nil)
     ;; Case 2. This is a deep sub-tree: export it as a list item.
     ;;         Also export as items headlines for which no section
     ;;         format has been found.
     ((org-export-low-level-p headline info)
      ;; Build the real contents of the sub-tree.
      (let* ((type (if numberedp 'ordered 'unordered))
	     (itemized-body (org-reveal-format-list-item
			     contents type nil nil 'none full-text)))
	(concat
	 (and (org-export-first-sibling-p headline info)
	      (org-html-begin-plain-list type))
	 itemized-body
	 (and (org-export-last-sibling-p headline info)
	      (org-html-end-plain-list type)))))
     ;; Case 3. Standard headline.  Export it as a section.
     (t
      (let* ((section-number (mapconcat 'number-to-string
					(org-export-get-headline-number
					 headline info) "-"))
	     (ids (remove 'nil
			  (list (org-element-property :CUSTOM_ID headline)
				(concat "sec-" section-number)
				(org-element-property :ID headline))))
	     (extra-ids (cdr ids))
	     (level1 (+ level (1- org-html-toplevel-hlevel)))
             (hlevel (org-reveal--get-hlevel info))
	     (first-content (car (org-element-contents headline))))
        (concat
         (if (or (/= level 1)
                 (not (org-export-first-sibling-p headline info)))
             ;; Stop previous slide.
             "</section>\n")
         (if (eq level hlevel)
             ;; Add an extra "<section>" to group following slides
             ;; into vertical ones.
             "<section>\n")
         ;; Start a new slide.
         (format "<section%s>\n"
                 (if-format " data-state=\"%s\"" (org-element-property :REVEAL_DATA_STATE headline)))
         ;; The HTML content of this headline.
         (format "\n<h%d%s>%s%s</h%d>\n"
                 level1
                 (if-format " class=\"fragment %s\""
                            (org-element-property :REVEAL-FRAG headline))
                 (mapconcat
                  (lambda (x)
                    (let ((id (org-export-solidify-link-text
                               (if (org-uuidgen-p x) (concat "ID-" x)
                                 x))))
                      (org-html--anchor id)))
                  extra-ids "")
                 full-text
                 level1)
         ;; When there is no section, pretend there is an empty
         ;; one to get the correct <div class="outline- ...>
         ;; which is needed by `org-info.js'.
         (if (not (eq (org-element-type first-content) 'section))
             (concat (org-html-section first-content "" info)
                     contents)
           contents)
         (if (= level hlevel)
             ;; Add an extra "</section>" to stop vertical slide
             ;; grouping.
             "</section>\n")
         (if (and (= level 1)
                  (org-export-last-sibling-p headline info))
             ;; Last head 1. Stop all slides.
             "</section>")))))))
  
(defgroup org-export-reveal nil
  "Options for exporting Orgmode files to reveal.js HTML pressentations."
  :tag "Org Export reveal")

(defun org-reveal--append-path (dir-name path-name)
  "Append `path-name' to the end of `dir-name' to form a legal path name."
  (concat (file-name-as-directory dir-name) path-name))

(defun org-reveal--append-pathes (dir-name pathes)
  "Append all the path names in `pathes' to the end of `dir-name'
to form a legal path name."
  (if pathes
      (org-reveal--append-pathes
       (org-reveal--append-path dir-name (car pathes))
       (cdr pathes))
    dir-name))

  
(defun org-reveal-stylesheets (info)
  "Return the HTML contents for declaring reveal stylesheets
using custom variable `org-reveal-root'."
  (let* ((root-path (plist-get info :reveal-root))
         (css-dir-name (org-reveal--append-path root-path "css"))
         (min-css-file-name (org-reveal--append-path css-dir-name "reveal.min.css"))
         (theme-file (format "%s.css" (plist-get info :reveal-theme)))
         (theme-path (org-reveal--append-path css-dir-name "theme"))
         (theme-full (org-reveal--append-path theme-path theme-file)))
    (format "<link rel=\"stylesheet\" href=\"%s\">
    <link rel=\"stylesheet\" href=\"%s\" id=\"theme\">\n"
                min-css-file-name theme-full)))

(defun org-reveal-mathjax-scripts (info)
  "Return the HTML contents for declaring MathJax scripts"
  (if (plist-get info :reveal-mathjax)
      ;; MathJax enabled.
      (format "<script type=\"text/javascript\" src=\"%s\"></script>\n"
              (plist-get info :reveal-mathjax-url))))

(defun org-reveal-scripts (info)
  "Return the necessary scripts for initializing reveal.js using
custom variable `org-reveal-root'."
  (let* ((root-path (plist-get info :reveal-root))
         (root-dir-name (file-name-as-directory root-path))
         (lib-dir-name (org-reveal--append-path root-path "lib"))
         (lib-js-dir-name (org-reveal--append-path lib-dir-name "js"))
         (plugin-dir-name (org-reveal--append-path root-path "plugin"))
         (markdown-dir-name (org-reveal--append-path plugin-dir-name "markdown")))
    (concat
     (format "<script src=\"%s\"></script>\n<script src=\"%s\"></script>\n"
             (org-reveal--append-path lib-js-dir-name "head.min.js")
             (org-reveal--append-pathes root-path '("js" "reveal.min.js")))
     "<script>\n"
     (format "
        		// Full list of configuration options available here:
        		// https://github.com/hakimel/reveal.js#configuration
        		Reveal.initialize({
        			controls: %s,
        			progress: %s,
        			history: %s,
        			center: %s,

        			theme: Reveal.getQueryHash().theme, // available themes are in /css/theme
        			transition: Reveal.getQueryHash().transition || '%s', // default/cube/page/concave/zoom/linear/fade/none\n"
             (if (plist-get info :reveal-control) "true" "false")
             (if (plist-get info :reveal-progress) "true" "false")
             (if (plist-get info :reveal-history) "true" "false")
             (if (plist-get info :reveal-center) "true" "false")
             (plist-get info :reveal-trans))
     (format "
        			// Optional libraries used to extend on reveal.js
        			dependencies: [
        				{ src: '%s', condition: function() { return !document.body.classList; } },
        				{ src: '%s', condition: function() { return !!document.querySelector( '[data-markdown]' ); } },
        				{ src: '%s', condition: function() { return !!document.querySelector( '[data-markdown]' ); } },
        				{ src: '%s', async: true, callback: function() { hljs.initHighlightingOnLoad(); } },
        				{ src: '%s', async: true, condition: function() { return !!document.body.classList; } },
        				{ src: '%s', async: true, condition: function() { return !!document.body.classList; } }
        				// { src: '%s', async: true, condition: function() { return !!document.body.classList; } }
        				// { src: '%s', async: true, condition: function() { return !!document.body.classList; } }
        			]
        		});\n"
               (org-reveal--append-path lib-js-dir-name "classList.js")
               (org-reveal--append-path markdown-dir-name "showdown.js")
               (org-reveal--append-path markdown-dir-name "markdown.js")
               (org-reveal--append-pathes plugin-dir-name '("highlight" "highlight.js"))
               (org-reveal--append-pathes plugin-dir-name '("zoom-js" "zoom.js"))
               (org-reveal--append-pathes plugin-dir-name '("notes" "notes.js"))
               (org-reveal--append-pathes plugin-dir-name '("search" "search.js"))
               (org-reveal--append-pathes plugin-dir-name '("remotes" "remotes.js")))
                "</script>\n")))

(defun org-reveal-toc (depth info)
  "Build a slide of table of contents."
  (concat
   "<section>\n"
   (org-html-toc depth info)
   "</section>\n"))

(defun org-reveal-inner-template (contents info)
  "Return body of document string after HTML conversion.
CONTENTS is the transcoded contents string. INFO is a plist
holding export options."
  (concat
   ;; Table of contents.
   (let ((depth (plist-get info :with-toc)))
     (when depth (org-reveal-toc depth info)))
   ;; Document contents.
   contents))

(defun org-reveal-format-list-item
  (content type checkbox &optional term-counter-id frag headline)
  "Format a list item into Reveal.js HTML."
  (let ((checkbox (concat (org-html-checkbox checkbox) (and checkbox " "))))
    (concat
     (case type
       (ordered
        (concat
         "<li"
         (if-format " value=\"%s\"" counter)
         (if-format " class=\"fragment %s\"" frag)
         ">"
         (if headline (concat headline "<br/>"))))
       (unordered
        (concat
         "<li"
         (if-format " class=\"fragment %s\"" frag)
         ">"
         (if headline (concat headline "<br/>"))))
       (descriptive
        (concat
         "<dt"
         (if-format " class=\"fragment %s\"" frag)
         ">"
         (concat checkbox (or term-counter-id "(no term)"))
         "</dt><dd>")))
     (unless (eq type 'descriptive) checkbox)
     contents
     (case type
       (ordered "</li>")
       (unordered "</li>")
       (descriptive "</dd>")))))

(defun org-reveal--headline-property (property blob)
  "Get property from BLOB's parent headline and return."
  (let ((headline (if (eq (org-element-type blob) 'headline) blob
                    (org-export-get-parent-headline blob))))
    (org-element-property property headline)))
                  

(defun org-reveal--get-frag (info)
  "Get Reveal fragment settings from context."
  (let ((frag (plist-get info :reveal-frag)))
    (if (eq frag "none") nil frag)))

(defun org-reveal-item (item contents info)
  "Transcode an ITEM element from Org to Reveal.
CONTENTS holds the contents of the item. INFO is aplist holding
contextual information."
  (let* ((plain-list (org-export-get-parent item))
         (type (org-element-property :type plain-list))
         (counter (org-element-property :counter item))
         (checkbox (org-element-property :checkbox item))
         (tag (let ((tag (org-element-property :tag item)))
                (and tag (org-export-data tag info))))
         (frag (org-export-read-attribute :attr_reveal plain-list :frag)))
    (org-reveal-format-list-item
     contents type checkbox (or tag counter) frag)))

(defun org-reveal-paragraph (paragraph contents info)
  "Transcode a PARAGRAPH element from Org to Reveal HTML.
CONTENTS is the contents of the paragraph, as a string.  INFO is
the plist used as a communication channel."
  (let ((parent (org-export-get-parent paragraph)))
    (cond
     ((and (eq (org-element-type parent) 'item)
	   (= (org-element-property :begin paragraph)
	      (org-element-property :contents-begin parent)))
      ;; leading paragraph in a list item have no tags
      contents)
     ((org-html-standalone-image-p paragraph info)
      ;; standalone image
      contents)
     (t (format "<p%s>\n%s</p>"
                (if-format " class=\"fragment %s\""
                           (org-export-read-attribute :attr_reveal paragraph :frag))
                contents)))))


(defun org-reveal-template (contents info)
  "Return complete document string after HTML conversion.
contents is the transcoded contents string.
info is a plist holding export options."
  (concat
   (format "<!doctype html>\n<html%s>\n<head>\n"
           (if-format " lang=\"%s\"" (plist-get info :language)))
   (if-format "<title>%s</title>\n" (plist-get info :title))
   (if-format "<meta name=\"author\" content=\"%s\"/>\n" (plist-get info :author))
   (if-format "<meta name=\"description\" content=\"%s\"/>\n" (plist-get info :description))
   (if-format "<meta name=\"keywords\" content=\"%s\"/>\n" (plist-get info :keywords))
   (org-reveal-stylesheets info)
   (org-reveal-mathjax-scripts info)
   "</head>
<body>
<div class=\"reveal\">
<div class=\"slides\">
<section>
"
   (format-spec org-reveal-title-slide-template (org-html-format-spec info))
   "</section>\n"
   contents
   "</div>
</div>\n"
   (org-reveal-scripts info)
   "</body>
</html>\n"))



(defun org-reveal-export-to-html
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a reveal.js HTML file."
  (interactive)
  (let* ((extension (concat "." org-html-extension))
         (file (org-export-output-file-name extension subtreep)))
    (org-export-to-file
     'reveal file subtreep visible-only body-only ext-plist)))

(provide 'ox-reveal)
