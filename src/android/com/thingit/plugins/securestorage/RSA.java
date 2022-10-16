package com.thingit.plugins.securestorage;

import android.content.Context;
import android.security.KeyPairGeneratorSpec;
import android.security.keystore.UserNotAuthenticatedException;

import javax.crypto.Cipher;
import javax.security.auth.x500.X500Principal;
import java.math.BigInteger;
import java.security.Key;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.util.Calendar;

public class RSA {
    private static final String KEYSTORE_PROVIDER = "AndroidKeyStore";
    private static final Cipher CIPHER = getCipher();

    public static byte[] encrypt(byte[] buf, String alias) throws Exception {
        return runCipher(Cipher.ENCRYPT_MODE, alias, buf);
    }

    public static byte[] decrypt(byte[] buf, String alias) throws Exception {
        return runCipher(Cipher.DECRYPT_MODE, alias, buf);
    }

    public static void createKeyPair(Context ctx, String alias) throws Exception {
        Calendar notBefore = Calendar.getInstance();
        Calendar notAfter = Calendar.getInstance();
        notAfter.add(Calendar.YEAR, 100);
        String principalString = String.format("CN=%s, OU=%s", alias, ctx.getPackageName());
        KeyPairGeneratorSpec spec = new KeyPairGeneratorSpec.Builder(ctx)
                .setAlias(alias)
                .setSubject(new X500Principal(principalString))
                .setSerialNumber(BigInteger.ONE)
                .setStartDate(notBefore.getTime())
                .setEndDate(notAfter.getTime())
                .setEncryptionRequired()
                .setKeySize(2048)
                .setKeyType("RSA")
                .build();
        KeyPairGenerator kpGenerator = KeyPairGenerator.getInstance("RSA", KEYSTORE_PROVIDER);
        kpGenerator.initialize(spec);
        kpGenerator.generateKeyPair();
    }


    public static boolean isEntryAvailable(String alias) {
        try {
            return loadKey(Cipher.ENCRYPT_MODE, alias) != null;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean userAuthenticationRequired(String alias) {
        try {
            // Do a quick encrypt/decrypt test
            byte[] encrypted = encrypt(alias.getBytes(), alias);
            decrypt(encrypted, alias);
            return false;
        } catch (UserNotAuthenticatedException noAuthEx) {
            return true;
        } catch (Exception e) {
            // Other
            return false;
        }
    }

    private static byte[] runCipher(int cipherMode, String alias, byte[] buf) throws Exception {
        Key key = loadKey(cipherMode, alias);
        synchronized (CIPHER) {
            CIPHER.init(cipherMode, key);
            return CIPHER.doFinal(buf);
        }
    }

    private static Key loadKey(int cipherMode, String alias) throws Exception {
        KeyStore keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER);
        keyStore.load(null, null);
        Key key;
        switch (cipherMode) {
            case Cipher.ENCRYPT_MODE -> {
                key = keyStore.getCertificate(alias).getPublicKey();
                if (key == null) {
                    throw new Exception("Failed to load the public key for " + alias);
                }
            }
            case Cipher.DECRYPT_MODE -> {
                key = keyStore.getKey(alias, null);
                if (key == null) {
                    throw new Exception("Failed to load the private key for " + alias);
                }
            }
            default -> throw new Exception("Invalid cipher mode parameter");
        }
        return key;
    }

    private static Cipher getCipher() {
        try {
            return Cipher.getInstance("RSA/ECB/PKCS1Padding");
        } catch (Exception e) {
            return null;
        }
    }
}