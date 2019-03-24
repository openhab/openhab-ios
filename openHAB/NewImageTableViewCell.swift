//
//  NewImageTableViewCell.swift
//  DynamicCellHeightProgrammatic
//
//  Created by Tim Müller-Seydlitz on 24.02.19.
//  Copyright © 2019 Satinder. All rights reserved.
//

import UIKit

class NewImageTableViewCell: UITableViewCell {

    @IBOutlet weak var customImageView: ScaledHeightImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
