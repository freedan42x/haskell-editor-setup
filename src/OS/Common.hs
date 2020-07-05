module OS.Common where

import qualified Data.Text                     as DT
import           Data.Text.IO
import           Control.Monad                  ( filterM )
import           Prelude                 hiding ( die
                                                , putStrLn
                                                )
import qualified Relude.Unsafe                 as RU
import           System.Directory               ( doesFileExist
                                                , getHomeDirectory
                                                )
import qualified Turtle                        as T

isExecutableInPath :: T.FilePath -> IO Bool
isExecutableInPath name = isJust <$> T.which name

isGhcInstalled :: IO Bool
isGhcInstalled = isExecutableInPath "ghc"

isCabalInstalled :: IO Bool
isCabalInstalled = isExecutableInPath "cabal"

isStackInstalled :: IO Bool
isStackInstalled = isExecutableInPath "stack"

data NixConfiguration
  = User | NixOS deriving (Eq, Show)

doesFileExist' :: FilePath -> IO Bool
doesFileExist' path
  | "~" `isPrefixOf` path = do
    homepath <- getHomeDirectory
    doesFileExist $ homepath ++ RU.tail path
  | otherwise = doesFileExist path

getExistingNixConfigurations :: IO [NixConfiguration]
getExistingNixConfigurations = map fst <$> filterM
  (\(_, filePath) -> doesFileExist' filePath)
  nixConfigurationPaths

getNixConfigurationPath :: NixConfiguration -> Text
getNixConfigurationPath nixConfiguration =
  DT.pack $ snd $ RU.fromJust $ find ((==nixConfiguration).fst) nixConfigurationPaths

nixConfigurationPaths :: [(NixConfiguration, FilePath)]
nixConfigurationPaths =
  [ (User , "~/.config/nixpkgs/config.nix")
  , (NixOS, "/etc/nixos/configuration.nix")
  ]

-- TODO user User over NixOS only if it has packages installed in it
getOptimalNixConfiguration :: IO NixConfiguration
getOptimalNixConfiguration = do
  configurations <- getExistingNixConfigurations
  return $ if configurations == [NixOS] then NixOS else User

runShellCommand :: Text -> IO Text
runShellCommand command =
  fmap unlines $ T.sortOn (const 42:: a -> Int) $ do
    out <- T.inshellWithErr command empty
    return $ T.lineToText $ bifold out

runAsUserCmdPrefix :: Text -> Text
runAsUserCmdPrefix cmd = "sudo -u $SUDO_USER " <> cmd

isAtomPackageInstalled :: Text -> IO Bool
isAtomPackageInstalled _name = do
  list <- runShellCommand "apm list --installed --bare --color false"
  return $ _name `elem` map (RU.head . DT.splitOn "@") (lines list)

installAtomPackage :: Text -> IO ()
installAtomPackage atomPackage = do
  putStrLn $ "Installing " <> atomPackage <> " Atom atomPackage"
  T.shell (runAsUserCmdPrefix $ "apt install --color false " <> atomPackage) empty >>= \case
    T.ExitSuccess -> putStrLn $ atomPackage <> " successfully installed"
    T.ExitFailure n ->
      T.die $ atomPackage <> " installation failed with exit code: " <> T.repr n