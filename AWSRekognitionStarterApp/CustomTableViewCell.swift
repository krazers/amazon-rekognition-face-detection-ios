//
//  CustomTableViewCell.swift
//  AWSRekognitionStarterApp
//
//  Created by Azer, Chris on 5/12/19.
//  Copyright © 2019 AWS. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation

class CustomTableViewCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var simularity: UILabel!
    
    @IBOutlet var imageicon: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        imageicon.layer.cornerRadius = 10.0
        /*imageicon.layer.borderWidth = 1
        imageicon.layer.masksToBounds = false
        imageicon.layer.borderColor = UIColor.black.cgColor
        imageicon.layer.cornerRadius = imageicon.frame.height/2
        imageicon.clipsToBounds = true*/
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
