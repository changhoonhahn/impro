;+
; NAME:
;   DEEP2_TO_MAGGIES
;
; PURPOSE:
;   Convert the DEEP2 extended galaxy photometry (from Matthews et
;   al. 2013) to AB maggies. 
;
; INPUTS: 
;   cat - input photometric catalog [NGAL] 
;
; KEYWORD PARAMETERS:
;   field24 - Fields 2-4 are calibrated on the SDSS system whereas Field 1 is on
;     the CFHTLS photometric system.
;
; OUTPUTS: 
;   maggies - output maggies [8,NGAL]
;   ivarmaggies - corresponding inverse variance array [8,NGAL]  
;
; COMMENTS:
;   A minimum error of 0.02 mag is applied to every bandpass.
;
;   Note that the Field 1 photometry from Matthews+13 is from CFHTLS while the
;   Field 3-4 photometry is calibrated on the SDSS photometric system.  However,
;   we only return the CFHTLS filters, so beware!
;
; MODIFICATION HISTORY:
;   J. Moustakas, 2013 Jul 14, Siena
;   jm16feb02siena - added comment about the CFHTLS vs SDSS bands
;
; Copyright (C) 2013, John Moustakas
; 
; This program is free software; you can redistribute it and/or modify 
; it under the terms of the GNU General Public License as published by 
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version. 
; 
; This program is distributed in the hope that it will be useful, but 
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details. 
;-

pro deep2_to_maggies, cat, maggies, ivarmaggies, unwise=unwise, $
  filterlist=filterlist, field24=field24, _extra=extra

    nobj = n_elements(cat)
    if (nobj eq 0L) then begin
       doc_library, 'deep2_to_maggies'
       return
    endif

    filterlist = deep2_filterlist(field24=field24)
    names = ['best'+['b','r','i'],['u','g','r','i','z']]
    errnames = ['best'+['b','r','i']+'err',['u','g','r','i','z']+'err']
    nband = n_elements(names)
    minerrors = replicate(0.02,nband)

; the DEEP2 photometry has been corrected for reddening while the CFHTLS/SDSS
; photometry has not; use the reddening value contained within the catalog for
; consistency
    weff = k_lambda_eff(filterlist=filterlist)
    kl = k_lambda(weff,/odonnell,/silent)
    kl[0:2] = 0.0 ; do not correct for reddening
;   glactc, cat.ra_deep, cat.dec_deep, 2000.0, gl, gb, 1, /deg
;   ebv = dust_getval(gl,gb,/interp,/noloop)
;   niceprint, filterlist, weff, kl
    ebv = cat.sfd_ebv
    
; convert from Vega magnitudes 
    vega2ab = k_vega2ab(filterlist=filterlist,/kurucz,/silent)
    vega2ab = vega2ab*0 ; already in AB

    if keyword_set(unwise) then begin
       maggies = fltarr(nband+4,nobj)
       ivarmaggies = fltarr(nband+4,nobj)
    endif else begin
       maggies = fltarr(nband,nobj)
       ivarmaggies = fltarr(nband,nobj)
    endelse
    for iband = 0L, nband-1 do begin
       ftag = tag_indx(cat[0],names[iband]+'')
       utag = tag_indx(cat[0],errnames[iband])
       good = where((cat.(ftag) gt 0.0) and (cat.(ftag) lt 30.0) and $ ; note <30 mag!
         (cat.(utag) gt 0.0) and (cat.(utag) lt 5.0),ngood) ; note 5 mag!
       if (ngood ne 0) then begin
          mag = cat[good].(ftag) + vega2ab[iband] - kl[iband]*ebv[good]
          magerr = cat[good].(utag)
          maggies[iband,good] = 10.0^(-0.4*mag)
          notzero = where((maggies[iband,good] gt 0.0),nnotzero)
          if (nnotzero ne 0L) then ivarmaggies[iband,good[notzero]] = $
            1.0/(0.4*alog(10.0)*(maggies[iband,good[notzero]]*magerr[notzero]))^2
       endif 
    endfor

    k_minerror, maggies, ivarmaggies, minerrors

; add unWISE photometry
    if keyword_set(unwise) then begin
       unwise_to_maggies, cat, mm, ii, filterlist=ff, ebv=ebv
       maggies[nband:nband+3,*] = mm
       ivarmaggies[nband:nband+3,*] = ii
       filterlist = [filterlist,ff]
    endif
    
return
end
