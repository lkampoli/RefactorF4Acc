module IXYZ
      real, dimension(1:lx2,1:lx1) :: ixm12
      real, dimension(1:lx1,1:lx2) :: ixm21
      real, dimension(1:ly2,1:ly1) :: iym12
      real, dimension(1:ly1,1:ly2) :: iym21
      real, dimension(1:lz2,1:lz1) :: izm12
      real, dimension(1:lz1,1:lz2) :: izm21
      real, dimension(1:lx1,1:lx2) :: ixtm12
      real, dimension(1:lx2,1:lx1) :: ixtm21
      real, dimension(1:ly1,1:ly2) :: iytm12
      real, dimension(1:ly2,1:ly1) :: iytm21
      real, dimension(1:lz1,1:lz2) :: iztm12
      real, dimension(1:lz2,1:lz1) :: iztm21
      real, dimension(1:lx3,1:lx1) :: ixm13
      real, dimension(1:lx1,1:lx3) :: ixm31
      real, dimension(1:ly3,1:ly1) :: iym13
      real, dimension(1:ly1,1:ly3) :: iym31
      real, dimension(1:lz3,1:lz1) :: izm13
      real, dimension(1:lz1,1:lz3) :: izm31
      real, dimension(1:lx1,1:lx3) :: ixtm13
      real, dimension(1:lx3,1:lx1) :: ixtm31
      real, dimension(1:ly1,1:ly3) :: iytm13
      real, dimension(1:ly3,1:ly1) :: iytm31
      real, dimension(1:lz1,1:lz3) :: iztm13
      real, dimension(1:lz3,1:lz1) :: iztm31

      real, dimension(1:ly2,1:ly1) :: iam12
      real, dimension(1:ly1,1:ly2) :: iam21
      real, dimension(1:ly1,1:ly2) :: iatm12
      real, dimension(1:ly2,1:ly1) :: iatm21
      real, dimension(1:ly3,1:ly1) :: iam13
      real, dimension(1:ly1,1:ly3) :: iam31
      real, dimension(1:ly1,1:ly3) :: iatm13
      real, dimension(1:ly3,1:ly1) :: iatm31
      real, dimension(1:ly2,1:ly1) :: icm12
      real, dimension(1:ly1,1:ly2) :: icm21
      real, dimension(1:ly1,1:ly2) :: ictm12
      real, dimension(1:ly2,1:ly1) :: ictm21
      real, dimension(1:ly3,1:ly1) :: icm13
      real, dimension(1:ly1,1:ly3) :: icm31
      real, dimension(1:ly1,1:ly3) :: ictm13
      real, dimension(1:ly3,1:ly1) :: ictm31
      real, dimension(1:ly1,1:ly1) :: iajl1
      real, dimension(1:ly1,1:ly1) :: iatjl1
      real, dimension(1:ly2,1:ly2) :: iajl2
      real, dimension(1:ly2,1:ly2) :: iatjl2
      real, dimension(1:ly3,1:ly3) :: ialj3
      real, dimension(1:ly3,1:ly3) :: iatlj3
      real, dimension(1:ly1,1:ly1) :: ialj1
      real, dimension(1:ly1,1:ly1) :: iatlj1

end module IXYZ
