#!/bin/bash
# Installation openssh
echo "Mise à jour des paquets et installation d'OpenSSH..."
sudo apt-get update
sudo apt-get install openssh-server openssh-client

# Demande du nom d'utilisateur SFTP principal
while true; do
    echo "Entrez le nom de l'utilisateur SFTP principal à créer :"
    read -r USERNAME
    if id -u "$USERNAME" >/dev/null 2>&1; then
        echo "L'utilisateur $USERNAME existe déjà. Veuillez choisir un autre nom."
    elif [ -z "$USERNAME" ]; then
        echo "Le nom d'utilisateur ne peut pas être vide. Veuillez entrer un nom d'utilisateur."
    else
        break
    fi
done

# Demande du mot de passe de l'utilisateur SFTP principal
while true; do
    echo "Entrez le mot de passe pour l'utilisateur $USERNAME :"
    read -s -r PASSWORD
    if [[ ${#PASSWORD} -lt 12 || "$PASSWORD" != *[A-Z]* || "$PASSWORD" != *[a-z]* || "$PASSWORD" != *[0-9]* ]]; then
        echo "Le mot de passe doit contenir au moins 12 caractères, dont une lettre majuscule, une lettre minuscule et un chiffre."
    else
        break
    fi
done

# Configuration SFTP
# Création de l'arborescence sftp
echo "Création de l'arborescence SFTP pour l'utilisateur $USERNAME..."
sudo mkdir -p /sftp/"$USERNAME"/
sudo chown root /sftp/"$USERNAME"
sudo chmod 755 /sftp/"$USERNAME"

# Création des utilisateurs
echo "Création de l'utilisateur $USERNAME..."
sudo groupadd sftpusers
sudo useradd -g sftpusers -d /sftp/"$USERNAME" -s /usr/sbin/nologin "$USERNAME"
echo "$USERNAME:$PASSWORD" | sudo chpasswd
sudo chown root:sftpusers /sftp/"$USERNAME"
sudo chown -R "$USERNAME":sftpusers /sftp/"$USERNAME"

# Demande si l'utilisateur veut créer des utilisateurs supplémentaires
while true; do
    echo "Voulez-vous créer des utilisateurs supplémentaires ? (Oui/Non)"
    read -r ADD_USERS
    if [[ $ADD_USERS = "Oui" ]]; then
        # Demande du nombre d'utilisateurs supplémentaires à créer
        while true; do
            echo "Combien d'utilisateurs supplémentaires voulez-vous créer ?"
            read -r USERCOUNT
            if ! [[ "$USERCOUNT" =~ ^[0-9]+$ ]]; then
                echo "Veuillez entrer un nombre valide."
            elif [ "$USERCOUNT" -eq 0 ]; then
                echo "Aucun utilisateur supplémentaire à créer."
                break 2
            else
                break
            fi
        done
        # Création des utilisateurs supplémentaires
        for ((i=1; i<=USERCOUNT; i++)); do
            while true; do
                echo "Entrez le nom de l'utilisateur SFTP $i à créer :"
                read -r SUBUSERNAME
                if id -u "$SUBUSERNAME" >/dev/null 2>&1; then
                    echo "L'utilisateur $SUBUSERNAME existe déjà. Veuillez choisir un autre nom."
                elif [ -z "$SUBUSERNAME" ]; then
                    echo "Le nom d'utilisateur ne peut pas être vide. Veuillez entrer un nom d'utilisateur."
                else
                    break
                fi
            done
            while true; do
                echo "Entrez le mot de passe pour l'utilisateur $SUBUSERNAME :"
                read -s -r SUBPASSWORD
                if [[ ${#SUBPASSWORD} -lt 12 || "$SUBPASSWORD" != *[A-Z]* || "$SUBPASSWORD" != *[a-z]* || "$SUBPASSWORD" != *[0-9]* ]]; then
                    echo "Le mot de passe doit contenir au moins 12 caractères, dont une lettre majuscule, une lettre minuscule et un chiffre."
                else
                    break
                fi
            done
            sudo mkdir -p /sftp/"$USERNAME"/"$SUBUSERNAME"
            sudo chown root:sftpusers /sftp/"$USERNAME"/"$SUBUSERNAME"
            sudo useradd -g sftpusers -d /sftp/"$USERNAME"/"$SUBUSERNAME" -s /usr/sbin/nologin "$SUBUSERNAME"
            echo "$SUBUSERNAME:$SUBPASSWORD" | sudo chpasswd
        done
    elif [[ $ADD_USERS = "Non" ]]; then
        break
    else
        echo "Veuillez répondre par Oui ou Non."
    fi
done

echo "Configuration du serveur SFTP ..."

# Configurer le démon SSH pour le groupe sftpusers
sudo bash -c 'echo "" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "#Configuration du serveur SFTP ..." >> /etc/ssh/sshd_config'
sudo bash -c 'echo "Match Group sftpusers" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "    ChrootDirectory %h" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "    AllowTcpForwarding no" >> /etc/ssh/sshd_config'
sudo bash -c 'echo "    ForceCommand internal-sftp" >> /etc/ssh/sshd_config'

# Redémarrer le service SSH
if ! sudo systemctl restart ssh; then
    echo "Le service SSH n'a pas pu démarrer. Veuillez vérifier votre configuration ou le demarrer manuellement."
    exit 1
fi

echo "La configuration du serveur SFTP est terminée ..."