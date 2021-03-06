;+
; NAME:
;   IM_READ_STARBURST99()
;
; PURPOSE:
;   Read the Starburst99 spectra and data files into a structure. 
;
; INPUTS:
;   rootname - root name of all the output files generated by SB99
;     (this is the 'model designation' parameter)
;
; OPTIONAL INPUTS:
;
; KEYWORD PARAMETERS:
;
; OUTPUTS:
;   sb99 - output data structure
;
; OPTIONAL OUTPUTS:
;
; COMMENTS:
;   See http://www.stsci.edu/science/starburst99/docs/run.html for a
;   description of the various output files.
; 
;   Currently only reads the SPECTRUM (7), QUANTA (1), EWIDTH (10),
;   YIELD (6), and POWER (4) files.
;
; MODIFICATION HISTORY:
;   J. Moustakas, 2010 Mar 12, UCSD
;   jm13aug03siena - more clever I/O
;
; Copyright (C) 2010, 2013, John Moustakas
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

function im_read_starburst99, rootname, path=path

    if n_elements(rootname) eq 0 then begin
       doc_library, 'im_read_starburst99'
       return, -1
    endif

    if n_elements(path) eq 0 then path = './'
    
; construct the file names
    specfile = path+rootname+'.spectrum1'
    quantafile = path+rootname+'.quanta1'
    ewidthfile = path+rootname+'.ewidth1'
    yieldfile = path+rootname+'.yield1'
    
    if file_test(specfile) eq 0 then begin
       print, 'SPECTRUM file '+specfile+' not found'
       return, -1
    endif
    if file_test(quantafile) eq 0 then $
      print, 'QUANTA file '+specfile+' not found...skipping'
    if file_test(ewidthfile) eq 0 then $
      print, 'EWIDTH file '+specfile+' not found...skipping'
    if file_test(yieldfile) eq 0 then $
      print, 'YIELD file '+specfile+' not found...skipping'
    
; read the spectrum file, parse, and pack into a data structure
    splog, 'Reading '+specfile
    readfast, specfile, data, skip=6, /double
    allage = reform(data[0,*])
    age = allage[uniq(allage,sort(allage))]
    nage = n_elements(age)
    for ii = 0L, nage-1 do begin
       these = where(age[ii] eq allage,npix)
       if (ii eq 0) then begin
          sb99 = {$
            age:        fltarr(nage),$
            wave:       float(reform(data[1,these])),$ ; [Angstrom]
            flux_stars: fltarr(npix,nage),$
            flux_gas:   fltarr(npix,nage),$
            flux:       fltarr(npix,nage)}
       endif
       sb99.age[ii] = age[ii]                            ; [yr]
       sb99.flux_stars[*,ii] = 10D^reform(data[3,these]) ; [erg/s/A]
       sb99.flux_gas[*,ii] = 10D^reform(data[4,these])   ; [erg/s/A]
       sb99.flux[*,ii] = 10D^reform(data[2,these])       ; [erg/s/A]
    endfor

; check for the QUANTA file (not fully parsed!)
    if file_test(quantafile) ne 0 then begin
       moretags = {nlyc: fltarr(nage), nlyc_hei: fltarr(nage), nlyc_heii: fltarr(nage)}
       sb99 = struct_addtags(temporary(sb99),moretags)
       splog, 'Reading '+quantafile
       readfast, quantafile, data, skip=7
       newage = reform(data[0,*]) ; this file has much higher time resolution
       sb99.nlyc      = interpol(reform(data[1,*]),newage,sb99.age)
       sb99.nlyc_hei  = interpol(reform(data[3,*]),newage,sb99.age)
       sb99.nlyc_heii = interpol(reform(data[5,*]),newage,sb99.age)
    endif
          
; check for the EWIDTH file
    if file_test(ewidthfile) ne 0 then begin
       moretags = {$
         ha_c:  fltarr(nage), ha:  fltarr(nage), ewha:  fltarr(nage),$    ; H-alpha
         hb_c:  fltarr(nage), hb:  fltarr(nage), ewhb:  fltarr(nage),$    ; H-beta
         pab_c: fltarr(nage), pab: fltarr(nage), ewpab: fltarr(nage),$    ; Pa-beta
         brg_c: fltarr(nage), brg: fltarr(nage), ewbrg: fltarr(nage)}     ; Br-gamma
       sb99 = struct_addtags(temporary(sb99),moretags)
       splog, 'Reading '+ewidthfile
       readfast, ewidthfile, data, skip=7
       newage = reform(data[0,*]) ; this file has much higher age resolution
; H-alpha
       sb99.ha_c = interpol(reform(data[1,*]),newage,sb99.age)
       sb99.ha   = interpol(reform(data[2,*]),newage,sb99.age)
       sb99.ewha = interpol(reform(data[3,*]),newage,sb99.age)
; H-beta
       sb99.hb_c = interpol(reform(data[4,*]),newage,sb99.age)
       sb99.hb   = interpol(reform(data[5,*]),newage,sb99.age)
       sb99.ewhb = interpol(reform(data[6,*]),newage,sb99.age)
; Pa-beta
       sb99.pab_c = interpol(reform(data[7,*]),newage,sb99.age)
       sb99.pab   = interpol(reform(data[8,*]),newage,sb99.age)
       sb99.ewpab = interpol(reform(data[9,*]),newage,sb99.age)
; Br-gamma
       sb99.brg_c = interpol(reform(data[10,*]),newage,sb99.age)
       sb99.brg   = interpol(reform(data[11,*]),newage,sb99.age)
       sb99.ewbrg = interpol(reform(data[12,*]),newage,sb99.age)
    endif

; check for the YIELD file (not fully parsed!)
    if file_test(yieldfile) ne 0 then begin
       moretags = {$
         yield_h:  fltarr(nage),$
         yield_he: fltarr(nage),$
         yield_c:  fltarr(nage),$
         yield_n:  fltarr(nage),$
         yield_o:  fltarr(nage),$
         yield_mg: fltarr(nage),$
         yield_si: fltarr(nage),$
         yield_s:  fltarr(nage),$
         yield_fe: fltarr(nage)}
       sb99 = struct_addtags(temporary(sb99),moretags)
       splog, 'Reading '+yieldfile
       readfast, yieldfile, data, skip=7
       newage = reform(data[0,*]) ; this file has much higher age resolution
       sb99.yield_h  = interpolate(reform(data[1,*]),findex(newage,sb99.age))
       sb99.yield_he = interpolate(reform(data[2,*]),findex(newage,sb99.age))
       sb99.yield_c  = interpolate(reform(data[3,*]),findex(newage,sb99.age))
       sb99.yield_n  = interpolate(reform(data[4,*]),findex(newage,sb99.age))
       sb99.yield_o  = interpolate(reform(data[5,*]),findex(newage,sb99.age))
       sb99.yield_mg = interpolate(reform(data[6,*]),findex(newage,sb99.age))
       sb99.yield_si = interpolate(reform(data[7,*]),findex(newage,sb99.age))
       sb99.yield_s  = interpolate(reform(data[8,*]),findex(newage,sb99.age))
       sb99.yield_fe = interpolate(reform(data[9,*]),findex(newage,sb99.age))
    endif

return, sb99
end
