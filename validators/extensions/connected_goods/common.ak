use aiken/primitive/bytearray.{length, starts_with}

pub type ConnectedGood {
  token_name: ByteArray,
  password: ByteArray,
}

pub type ConnectedGoodsDatum {
  id: ByteArray,
  items: List<ConnectedGood>,
}

pub type SocialHubDatum {
  owner: ByteArray,
  batch_id: ByteArray,
  picture: Option<ByteArray>,
  name: Option<ByteArray>,
  subtitle: Option<ByteArray>,
  x: Option<ByteArray>,
  telegram: Option<ByteArray>,
  instagram: Option<ByteArray>,
  discord: Option<ByteArray>,
  reddit: Option<ByteArray>,
  youtube: Option<ByteArray>,
  linkedin: Option<ByteArray>,
  github: Option<ByteArray>,
  website: Option<ByteArray>,
  adahandle: Option<ByteArray>,
  email: Option<ByteArray>,
}

pub fn datum_is_valid(datum: SocialHubDatum) {
  and {
    is_picture_valid(datum.picture),
    is_valid_username(datum.name),
    is_valid_username(datum.subtitle),
    is_valid_username(datum.x),
    is_valid_username(datum.telegram),
    is_valid_username(datum.instagram),
    is_valid_username(datum.discord),
    is_valid_username(datum.reddit),
    is_valid_username(datum.youtube),
    is_valid_username(datum.linkedin),
    is_valid_username(datum.github),
    is_valid_username(datum.adahandle),
    is_valid_username(datum.email),
    is_valid_url(datum.website),
  }
}

fn is_picture_valid(picture: Option<ByteArray>) {
  if picture == None {
    True
  } else {
    expect Some(picture) = picture
    length(picture) < 32
  }
}

fn is_valid_url(url: Option<ByteArray>) {
  if url == None {
    True
  } else {
    expect Some(url) = url

    and {
      length(url) > 0,
      length(url) < 160,
      or {
        starts_with(url, prefix: "http://"),
        starts_with(url, prefix: "ipfs://"),
        starts_with(url, prefix: "https://"),
      },
    }
  }
}

fn is_valid_username(username: Option<ByteArray>) {
  if username == None {
    True
  } else {
    expect Some(username) = username

    and {
      length(username) > 0,
      length(username) < 160,
    }
  }
}
