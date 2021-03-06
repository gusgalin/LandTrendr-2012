pro make_cloudmask_quickview, path, cloudfile=cloudfile

  ;restore, image_info_savefile
  
  lt_images = strcompress(path+'images\', /rem)
  image_info = find_landtrendr_files_for_cost(lt_images, /ignore_ref)
  image_info = vct_repopulate_image_info(image_info, /from_auto)
  
  if keyword_set(cloudfile) eq 1 then begin
    cldfilebase = file_basename(cloudfile)
    match = strcompress("*"+strmid(cldfilebase,0,18)+"*", /rem)
    index = where(strmatch(image_info.image_file, match) eq 1, n_index)
    if n_index eq 1 then image_info = image_info[index] else message, ">>> no match found"
  endif
  
  for i=0, n_elements(image_info)-1 do begin
        
    
    image = image_info[i].image_file
    mask = image_info[i].cloud_file
    image_base = file_basename(image)
    base = file_basename(mask)
    
    ;check the mask
    if file_test(mask) eq 0 then begin
      print, ">>> mask for image: ", image_base, " does not exists, skipping..."
      continue
    endif
    
    ;check for existence of a quickview image
    name = stringswap(base, ".bsq", ".tif")
    output_tiff = strcompress(path+"\cloudmasks\"+string(image_info[i].year)+ $
        "_"+string(image_info[i].julday)+"_"+name, /rem)
    
    if file_test(output_tiff) eq 1 then continue
    
    print, ">>> making cloudmask quickview for image: ", image_base
    
    ;get the subset
    zot_img, image, hdr, img, /hdronly
    zot_img, mask, depmaskhdr, depmaskimg, /hdronly
    
    subset = [ [max([depmaskhdr.upperleftcenter[0], hdr.upperleftcenter[0]]), $
      min([depmaskhdr.upperleftcenter[1], hdr.upperleftcenter[1]])], $
      [min([depmaskhdr.lowerrightcenter[0], hdr.lowerrightcenter[0]]), $
      max([depmaskhdr.lowerrightcenter[1], hdr.lowerrightcenter[1]])] ]
      
    ;load in the image and its mask
    zot_img, image, hdr, img, layers = [1], subset=subset
    zot_img, mask, depmaskhdr, depmaskimg, subset=subset
    
    ;get things prepared for congrid and display size
    maxsize = float(max([hdr.filesize[0],hdr.filesize[1]]))
    wsize = 1200
    denom = float(wsize/maxsize)
    xsize = round(hdr.filesize[0]*denom)
    ysize = round(hdr.filesize[1]*denom)
    
    ;reduce the resolution
    imgnomask = reverse(congrid(img, xsize, ysize, 3),2)  ;hist_equal(,  minv=10, maxv=175)
    
;    for r=0, 0 do begin
;      ;zot_img, image, hdr, img, layers = 3-r, subset=subset
;      img[*,*,r] = img[*,*,r]*depmaskimg
;    endfor
    
    ;do the masked version
    img = temporary(img)*depmaskimg
    img = reverse(congrid(temporary(img), xsize, ysize, 3),2)  ;hist_equal(,  minv=10, maxv=175)
    
;    ;now do 5,4,3
;    zot_img, image, hdr, img543, layers = [5,4,3], subset=subset
;    ;reduce the resolution
;    imgnomask543 = reverse(congrid(img543, xsize, ysize, 3),2)  ;hist_equal(,  minv=10, maxv=175)
;    for r=0, 2 do begin
;      ;zot_img, image, hdr, img1, layers = 3-r, subset=subset
;      temp = img543[*,*,r]
;      temp[where(depmaskimg eq 0)] = colors1[r]
;      img543[*,*,r] = temporary(temp)
;      ;img543[*,*,r] = img543[*,*,r]*depmaskimg
;    endfor
;    img543 = reverse(congrid(temporary(img543), xsize, ysize, 3),2)  ;hist_equal(,  minv=10, maxv=175)
    
    ;now do 5,4,3
    zot_img, image, hdr, imgnomask543, layers = [5,4,3], subset=subset
    ;reduce the resolution
    imgnomask543 = reverse(congrid(temporary(imgnomask543), xsize, ysize, 3),2)  ;hist_equal(,  minv=10, maxv=175)
    
    colors1 = [255,255,0] ;yellow
    
    zot_img, image, hdr, b5, layers = 5, subset=subset
    b5[where(depmaskimg eq 0)] = colors1[0]
    b5 = reverse(congrid(temporary(b5), xsize, ysize, 1),2)  ;hist_equal(,  minv=10, maxv=175)
    
    zot_img, image, hdr, b4, layers = 4, subset=subset
    b4[where(depmaskimg eq 0)] = colors1[1]
    b4 = reverse(congrid(temporary(b4), xsize, ysize, 1),2)  ;hist_equal(,  minv=10, maxv=175)
    
    zot_img, image, hdr, b3, layers = 3, subset=subset
    b3[where(temporary(depmaskimg) eq 0)] = colors1[2]
    b3 = reverse(congrid(temporary(b3), xsize, ysize, 1),2)  ;hist_equal(,  minv=10, maxv=175)
    
    img543 = [[[temporary(b5)]],[[temporary(b4)]],[[temporary(b3)]]]
    ;img543 = reverse(congrid(temporary(img543), xsize, ysize, 3),2)  ;hist_equal(,  minv=10, maxv=175)
    
    ;display them
    title = file_basename(image)
    window, 0, xsize=wsize*2, ysize=wsize*2, title=title;create a window to hold all of the regression tifs
    tv, temporary(imgnomask), 0;, true=3
    tv, temporary(img), 1;, true=3
    tv, temporary(imgnomask543), 2, true=3
    tv, temporary(img543), 3, true=3
    
    bbb = tvrd(/true)
    file_mkdir, path+"cloudmasks"
    
    ;name = stringswap(base, ".bsq", ".tif")
    ;output_tiff = strcompress(path+"\cloudmasks\"+string(image_info[i].year)+ $
    ;   "_"+string(image_info[i].julday)+"_"+name, /rem)
    
    lt_delete_duplicate, output_tiff, /cloudmsktif
    
    write_tiff, output_tiff, reverse(temporary(bbb),3)
    wdelete
  
  endfor
end