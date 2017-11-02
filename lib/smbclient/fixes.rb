# SMBClient fix
class File
  def self.catname(from, to)
    if directory? to
      join to, basename(from)
    else
      to
    end
  end
end
